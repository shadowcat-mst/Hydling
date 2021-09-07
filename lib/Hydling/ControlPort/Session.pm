package Hydling::ControlPort::Session;

use Mojo::JSON;
use Hydling::Class;

has stream => undef;
has buf => '';
has barfed => 0;
has handlers => undef;
has running => sub { {} };

sub start ($self) {
  $self->buf;
  $self->stream->on(close => $self->curry::weak::close);
  $self->stream->on(read => $self->curry::weak::read);
  $self;
}

sub read ($self, $stream, $data) {
  my \$buf = \$self->{buf};
  $buf .= $data;
  while ($buf =~ s/^(.*)\r?\n//ms) {
    my $line = $1;
    my @command = do {
      try {
        @{decode_json($line)};
      } catch ($err) {
        return $self->barf(protocol => $err);
      }
    };
    $self->dispatch(@command);
    return if $self->barfed;
  }
  return;
}

sub dispatch ($self, @command) {
  return if $self->barfed;
  my $tag = (
    ($command[0]//'') =~ /^[A-Z]+[0-9]+$/
      ? shift(@command)
      : ''
  );
  return $self->barf(protocol => "Empty command")
    unless @command;
  my $type = shift @command;
  return $self->barf(protocol => "Command type should be a string")
    if ref($type);
  my $method = "handle_${type}";
  return $self->barf(protocol => "Invalid command type ${type}")
    unless $self->can($method);
  return $self->barf(protocol => "Empty command args")
    unless @command;
  try {
    $self->${\"handle_${type}"}($type, $tag, @command);
  } catch ($err) {
    return $self->barf(internal => $err);
  }
}

sub barf ($self, $stream, @barf) {
  $self->barfed(1)->stream->write(
    encode_json([ bar => @barf ])."\n",
    $stream->curry::weak::close,
  );
  return;
}

sub send ($self, @send) {
  my $data = do {
    try {
      encode_json(\@send)."\n";
    } catch ($err) {
      return $self->barf(internal => "Couldn't serialise message: $err");
    }
  };
  $self->stream->write($data);
  return $self;
}

sub handle_call { shift->_handle_request(@_) }
sub handle_cast { shift->_handle_request(@_) }
sub handle_listen { shift->_handle_request(@_) }

sub _request_class ($self, $type) {
  my $class = "Hydling::ControlPort::${\ucfirst($type)}Request";
  state %loaded;
  $loaded{$class} ||= do { require join('/', split '::', $class).'.pm'; 1 };
  $class;
}

sub _handle_request ($self, $type, $tag, $name, @args) {
  if (my $running = $self->running->{$tag}) {
    return $self->barf(protocol => "Duplicate use of tag $tag") if $tag;
    $running->awaitable->AWAIT_ON_READY(sub {
      $self->dispatch($type, $tag, $name, @args);
    });
    return;
  }
  $self->_request_class($type)->new(
    tag => $tag,
    name => $name,
    args => \@args,
    session => $self,
  )->dispatch;
  return;
}

1;
