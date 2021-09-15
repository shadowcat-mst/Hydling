package Hydling::HasControlPort;

use Mojo::StupidRPC;
use Hydling::Base -role;

has 'ctl_path';

requires 'setup_handlers';

before start => sub ($self) {
  unlink($self->ctl_path);
  my $handlers = Mojo::StupidRPC->handler_set;
  $self->setup_handlers($handlers);
  Mojo::StupidRPC->server(
    { path => $self->ctl_path },
    $handlers,
  );
};

1;
