package Hydling::ControlPort;

use Safe::Isa;
use Mojo::JSON qw(encode_json decode_json);
use Hydling::Class;

has 'socket_path';

has 'acceptor_id';

has dispatch_call => sub { sub { 'nope' } };
has dispatch_listen => sub { sub { 'nope' } };
has dispatch_trap => sub { sub { 'nope' } };

has clients => sub { {} };

has in_flight_by_tag => sub { {} };

has in_flight_by_awaitable => sub { {} };

sub start ($self) {
  unlink $self->socket_path;
  $self->acceptor_id(Mojo::IOLoop->server(
    path => $self->socket_path,
    $self->curry::client_start,
  ));
}

sub stop ($self) {
  Mojo::IOLoop->acceptor($self->acceptor_id)->stop;
}

sub client_start ($self, $, $stream, $) {
  $self->clients->{$stream} = {
    input => '',
    stream => $stream,
    in_flight => {},
  };
  $stream->on(close => $self->curry::weak::client_close);
  $stream->on(read => $self->curry::weak::client_read);
  $self;
}

sub client_close ($self, $stream) {
  my \%state = delete $self->clients->{$stream};
  my \%by_tag = $self->in_flight_by_tag;
  my \%by_awaitable = $self->in_flight_by_awaitable;
  foreach my $in_flight (values %{$state{in_flight}}) {
    delete $by_tag{$in_flight->{tag}};
    delete $by_awaitable{$in_flight->{awaitable}};
  }
}

sub client_read ($self, $stream, $data) {
  my \%state = $self->clients->{$stream};
  $state{input} .= $data;
  while ($state{input} =~ s/^(.*)\r?\n//ms) {
    my $line = $1;
    my @command;
    try {
      @command = @{decode_json($line)};
    } catch ($err) {
      return $self->client_barf($stream, encoding => $err);
    }
    my $tag = (
      ($command[0]//'') =~ /^[A-Z]+[0-9]+$/
        ? shift(@command)
        : ''
    );
    return $self->client_barf($stream, encoding => "Empty command")
      unless @command;
    my $type = shift @command;
    state %is_command_type = (
      map +($_ => 1),
        qw(call cast listen unlisten trap untrap)
    );
    return $self->client_barf($stream, encoding => "Invalid command type")
      unless $is_command_type{$type//''};
    return $self->client_barf($stream, encoding => "Empty command args")
      unless @command;
    try {
      $self->${\"handle_${type}"}(join(':', $type, $tag) => @command);
    } catch ($err) {
      return $self->client_barf($stream, $type => "Internal error: $err");
    }
    return if $state{barfed};
  }
}

sub client_barf ($self, $stream, @barf) {
  $self->clients->{$stream}{barfed} = 1;
  $stream->write(
    encode_json([ bar => @barf ])."\n",
    $stream->curry::weak::close,
  );
  return;
}

sub client_send ($self, $stream, @data) {
  $stream->write(encode_json(\@data)."\n");
  return;
}

sub handle_call ($self, $stream, $tag, @call) {
  my \%by_tag = $self->in_flight_by_tag;
  if ($by_tag{$tag}) {
    return $self->client_barf(
      $stream, call => "Can't use already active tag ${tag}"
    );
  }
  my ($res, @extra) = do {
    try {
      $self->dispatch_call->(@call);
    } catch ($err) {
      (fail => $err);
    }
  };
  unless (ref $res) {
    state %is_res = (
      map +($_ => 1), qw(done fail nope)
    );
    return $self->client_barf(
      $stream, call => "Internal error: Malformed call result ${res}"
    ) unless $is_res{$res};
    return $self->client_send($stream, [ $res, @extra ]) unless ref($res);
  }
  unless ($res->$_can('AWAIT_ON_READY')) {
    return $self->client_barf(
      $stream,
      call => "Internal error: Malformed call result ${res}"
    );
  }
  $self->client_barf(
    $stream,
    call => "Internal error: Junk after call awaitable"
  ) if @extra;
  my \%in_flight = $self->clients->{$stream}{in_flight};
  my \%by_awaitable = $self->in_flight_by_awaitable;
  my $awaitable = $res;
  my $cs = $self->curry::weak::client_send($tag);
  $awaitable->AWAIT_IS_READY(sub {
    my $state = delete $in_flight{$tag};
    delete $by_tag{$tag};
    delete $by_awaitable{$awaitable};
    return if $state->{is_cast};
    try {
      my @res = $res->AWAIT_GET;
      $cs->(done => @res);
    } catch ($err) {
      $cs->(fail => $err);
    }
    return
  });
  return $in_flight{$tag} = $by_tag{$tag} = $by_awaitable{$awaitable} = {
    tag => $tag,
    stream => $stream,
    awaitable => $awaitable,
  };
}

sub handle_cast ($self, $stream, $tag, @call) {
  return $self->client_barf(cast => "Explicit tag not supported on cast")
    unless $tag eq 'cast:';
  try {
   state $tag_base = 'A0001';
    my $state = $self->handle_call(
      $stream, 
      "cast:".$tag_base++,
    );
    $state->{is_cast} = 1;
  } catch ($err) {
    return; # meh
  }
  return;
}

sub send_interim_data ($self, $aw, @data) {
  croak "send_interim_data: no such awaitable ${aw} in flight"
    unless my $state = $self->in_flight_by_awaitable->{$aw};
}

sub handle_listen { die }
sub handle_unlisten { die }
sub handle_trap { die }
sub handle_untrap { die }

1;
