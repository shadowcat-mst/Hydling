package Hydling::ControlPort::CastRequest;

use Hydling::Base;

with 'Hydling::ControlPort::Role::Request';

sub send { }

sub register { }

sub data { }

around receive => sub ($orig, $self, @args) => sub {
  return $self->session->barf(protocol => "Tag not allowed for cast")
    if $self->tag;
  $self->$orig(@args);
};

1;
