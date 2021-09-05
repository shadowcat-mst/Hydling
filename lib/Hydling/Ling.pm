package Hydling::Ling;

use Hydling::ControlPort;
use Mojo::IRC;
use Mojo::Base -base, -signatures, -async_await;

has 'control_port_path';

has 'control_port';

has 'irc';

sub control_port_config ($self) {
  return (
    socket_path => $self->control_port_path,
    dispatch_call => $self->curry::weak::dispatch_call,
    dispatch_listen => $self->curry::weak::dispatch_listen,
  );
}

sub start ($self) {
  $self->control_port(
    Hydling::ControlPort->new(
      $self->control_port_config
    )->start
  )->irc(Mojo::IRC->new->nick('hydling'));
}

sub dispatch_call ($self, $to, @args) {
  if ($to =~ /^(?:dis)?connect/) {
    return $self->irc->${\"${to}_p"};
  }
  if ($to eq 'write') {
    my @send = map +(ref($_) ? $self->irc->ctcp(@$_) : $_), @args;
    return $self->irc->write_p(@send);
  }
  state %is_setter = (
    map +($_ => 1),
      qw(connect_timeout local_address name nick pass real_host server)
  );
  if ($is_setter{$to}) {
    $self->$to($args[0]);
    return 'done';
  }
  return 'nope';
}

sub dispatch_listen ($self, $listener, $to, @) {
  state %is_event = (
    map +($_ => 1),
      qw(connecting connected disconnecting disconnected message status)
  );
  if (
    $is_event{$to}
    or $to =~ m/^(?:irc|ctcp)_/
  ) {
    my $notify = $self->curry::notify_listener($listener);
    $self->irc->on($to => $notify);
    return $self->irc->curry::unsubscribe($to => $notify);
  }
  return 'nope';
}

sub notify_listener ($self, $listener, $, $event, @payload) {
  $self->control_port->notify($listener, $event, @payload);
}

1;
