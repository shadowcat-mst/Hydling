package Hydling::ControlPort:;Role::HasHandlers;

use Hydling::Base -role;

has handlers => sub {
  state $loaded = do { require Hydling::ControlPort::Handlers; 1 };
  Hydling::ControlPort::Handlers->new
};

sub handle_call { shift->handlers->call(@_) }
sub handle_listen { shift->handlers->listen(@_) }
sub handle_trap { shift->handlers->trap(@_) }

1;
