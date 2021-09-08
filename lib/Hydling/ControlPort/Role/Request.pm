package Hydling::ControlPort::Role::Request;

use Hydling::Base -role;

has tag => undef;
has name => undef;
has args => undef;
has session => undef, weak => 1;
has awaitable => undef;
has call_complete => 0;

sub active { undef }

sub type ($self) {
  ref($self) =~ /::([A-Z][a-z]+)Request$/;
  lc($1)
}

sub send ($self, @send) {
  $self->session->send($self->tag//(), @send);
  $self
}

sub register ($self) {
  $self->session->running->{$self->tag} = $self;
  $self
}

sub deregister ($self) {
  delete $self->session->running->{$self->tag};
  $self
}

sub receive ($self) {
  my $handler = $self->session->handlers->lookup($self->type => $self->name);
  return $self->fail(undef) unless $handler;
  try {
    my @res = $self->${\$self->handler}(@{$self->args});
    if (@res and (my $awaitable = $res[0]->$_can('AWAIT_ON_READY'))) {
      $awaitable->AWAIT_ON_READY(sub ($aw) {
        $self->deregister->awaitable(undef);
        try {
          $self->done($aw->AWAIT_GET);
        } catch ($err) {
          $self->fail($err);
        }
        return;
      });
      return $self->register->awaitable($awaitable);
    }
    $self->done(@res) unless $self->call_complete;
  } catch ($err) {
    $self->fail($err) unless $self->call_complete;
  }
  return $self;
}

sub done ($self, @done) {
  croak "Request already completed" if $self->call_complete;
  $self->send(done => @done)->call_complete(1);
}

sub fail ($self, $fail) {
  croak "Request already completed" if $self->call_complete;
  $self->send(fail => $fail)->call_complete(1);
}

1;
