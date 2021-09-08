package Hydling::Ling;

use Hydling::ControlPort;
use Mojo::IRC;
use Hydling::Base;

has 'control_port_path';

has 'control_port';

has 'irc';

sub on { shift->irc->on(@_) }
sub unsubscribe { shift->irc->unsubscribe(@_) }

sub start ($self) {
  $self->control_port(
    Hydling::ControlPort->server(
      path => $self->control_port_path,
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
    my $cb = $self->on($name => sub ($, @args) { $r->notify(@args) });
    $r->on_cancel($self->curry::unsubscribe($name => $cb));
    return;
  });
  $h->listen(status => sub ($r) {
    my $cb = $self->on(status => sub ($, $value) {
      $r->notify($value);
    });
    $r->on_cancel($self->curry::unsubscribe(status => $cb));
    return $self->status;
  });
}

1;
