package Hydling::Ling;

use Mojo::IRC;
use Mojo::StupidRPC;
use Hydling::Base;

with 'Hydling::HasControlPort';

has 'irc';

sub setup_handlers ($self, $h) {
  Scalar::Util::weaken($self);
  foreach my $name (qw(connect disconnect)) {
    my $method = "${name}_p";
    $h->call($name => sub ($r, @) {
      $self->irc
           ->$method
           ->then(
               sub { $r->done },
               sub ($err) { $r->fail($err) },
             );
    });
  }
  $h->call(send => sub ($r, @args) {
    my $last = $args[-1];
    my @send = map {
      if (ref($_)) {
        $self->irc->ctcp(@$_)
      } elsif ($_ !~ / /) {
        $_
      } elsif ($_ eq $last) {
        ":$_"
      } else {
        return $r->fail("Invalid input for send")
      }
    } @args;
    $self->irc
         ->write_p(@send)
         ->then(
             sub { $r->done },
             sub ($self, $err) { $r->fail($err) },
           );
  });
  foreach my $accessor (
    qw(connect_timeout local_address name nick pass real_host server)
  ) {
    $h->call($accessor => sub ($r, @value) {
      $self->irc->$accessor($value[0]) if @value;
      $r->done($self->irc->$accessor);
    });
  }
  $h->call(status => sub ($r) { $r->done($self->irc->status) });
  foreach my $thing (qw(status message)) {
    $h->listen($thing => sub ($r) {
      Scalar::Util::weaken($r);
      my $name = $r->name;
      my $cb = $self->on($name => sub ($, @args) { $r->notify(@args) });
      $r->once(cancel => $self->curry::unsubscribe($name => $cb));
      $r->done($thing eq 'status' ? $self->irc->status : ());
      return;
    });
  }
}

sub on { shift->irc->on(@_) }
sub unsubscribe { shift->irc->unsubscribe(@_) }

sub start ($self) {
  $self->irc(Mojo::IRC->new->nick('hydling'));
}

1;
