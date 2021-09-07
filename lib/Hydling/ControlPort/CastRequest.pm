package Hydling::ControlPort::CastRequest;

use Hydling::Class 'Hydling::ControlPort::CallRequest';

sub send { }

sub register { }

around dispatch => sub ($orig, $self, @args) => sub {
  return $self->session->barf(protocol => "Tag not allowed for cast")
    if $self->tag;
  $self->$orig(@args);
};

1;
