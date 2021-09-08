package Hydling::ControlPort::Role::Subscription;

use Hydling::Base -role;

has on_cancel => undef;
has active => 0;

with 'Hydling::ControlPort::Role::Request';

after done => sub ($self, @) {
  $self->tag(join ':', $self->type, $self->name);
  $self->register;
  $self->active(1);
};

sub cancel ($self) {
  (delete $self->{on_cancel})->();
  $self->active(0);
}

1;
