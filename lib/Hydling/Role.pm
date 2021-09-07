package Hydling::Role;

use Import::Into;
use Mojo::Base -strict, -signatures;

sub import {
  Hydling::Class->import::into(1, -role);
}

1;
