package Hydling::ControlPort::ListenRequest;

use Hydling::Class 'Hydling::ControlPort::CallRequest';

has on_cancel => undef;
has active => 0;

after done => sub ($self, @) {
  $self->tag($self->name) unless $self->tag;
  $self->register;
  $self->active(1);
};

sub cancel ($self) {
  (delete $self->{on_cancel})->();
  $self->active(0);
}

sub notify ($self, @notify) {
  croak "Notify on inactive listener" unless $self->active;
  $self->send(notify => $self->name => @notify);
}

1;
