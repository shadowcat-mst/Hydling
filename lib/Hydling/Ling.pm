package Hydling::Ling;

use Hydling::ControlPort;
use Mojo::IRC;
use Hydling::Class;

has 'control_port_path';

has 'control_port';

has 'irc';

sub on { shift->irc->on(@_) }
sub unsubscribe { shift->irc->unsubscribe(@_) }

sub start ($self) {
  $self->control_port(
    Hydling::ControlPort->new(
    socket_path => $self->control_port_path,
    )
    ->tap($self->curry::control_port_setup)
    ->start
  )->irc(Mojo::IRC->new->nick('hydling'));
}

sub control_port_setup ($self, $control_port) {
  my $h = $control_port->handlers;
  foreach my $name (qw(connect disconnect)) {
    $h->call($name => sub { $self->irc->${\"${name}_p"} });
  }
  $h->call(write => sub ($r, @args) {
    my @send = map +(ref($_) ? $self->irc->ctcp(@$_) : $_), @args;
    $self->irc->write_p(@send);
  });
  foreach my $accessor (
    qw(connect_timeout local_address name nick pass real_host server)
  ) {
    $h->call($accessor => sub ($r, @value) {
      $self->$accessor($value[0]) if @value;
      return $self->$accessor;
    });
  }
  $h->listen(qr/^(?:irc|ctcp)_/, sub ($r) {
    my $name = $r->name;
    my $on = sub ($, @args) { $r->notify(@args) };
    my $cb = $self->on($name => $r->curry::notify);
    $r->on_cancel($self->curry::unsubscribe($name => $cb));
    return;
  });
  $h->watch(status => sub ($r) {
    my $cb = $self->on(status => sub ($, $value) {
      $r->value($value);
    });
    $r->on_cancel($self->curry::unsubscribe(status => $cb));
    $r->done->value($self->status);
  });
}

1;
