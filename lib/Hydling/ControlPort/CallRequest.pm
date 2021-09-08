package Hydling::ControlPort::CallRequest;

use Hydling::Base;

with 'Hydling::ControlPort::Role::Request';

sub data ($self, @data) { $self->send(data => @data) }

1;
