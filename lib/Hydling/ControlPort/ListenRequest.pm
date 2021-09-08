package Hydling::ControlPort::ListenRequest;

use Hydling::Base;

with 'Hydling::ControlPort::Role::Subscription';

sub notify ($self, @notify) {
  croak "Notify on inactive listener" unless $self->active;
  $self->send(notify => $self->name => @notify);
}

1;
