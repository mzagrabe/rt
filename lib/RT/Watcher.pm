# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#


package RT::Watcher;
use RT::Record;
@ISA= qw(RT::Record);



# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "Watchers";
  $self->_Init(@_);

  return($self);
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = (
	      Email => 'read/write',
	      Scope => 'read/write',
	      Value => 'read/write',
	      Type => 'read/write',
	      Quiet => 'read/write',
	      Template => 'read/write'	      
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}


# {{{ sub Create 
sub Create  {
  my $self = shift;
  my %args = (
	      Email => undef,
	      Value => undef,
	      Scope => undef,
	      Type => undef,
	      Template => undef,
	      Quiet => 0,
	      @_ # get the real argumentlist
	     );
  
  

  my $id = $self->SUPER::Create(%args);
  $self->Load($id);
  
  #TODO: this is horrificially wasteful. we shouldn't commit 
  # to the db and then instantly turn around and load the same data
  
  return (1,"Interest noted");
}
# }}}
 
# {{{ sub Load 
sub Load  {
  my $self = shift;
  my $identifier = shift;
  
  if ($identifier !~ /\D/) {
    $self->SUPER::LoadById($identifier);
  }
  else {
	return (0, "That's not a numerical id");
  }
}
# }}}

# {{{ sub UserObj 
sub UserObj  {
  my $self = shift;
  if (!defined $self->{'UserObj'}) {
    require RT::User;
    $self->{'UserObj'} = new RT::User($self->CurrentUser);
    $self->{'UserObj'}->Load($self->Email);
  }
  return ($self->{'UserObj'});
}
# }}}

# {{{ sub DisplayPermitted 
sub DisplayPermitted  {
  my $self = shift;
  #TODO: Implement
  return(1);
}
# }}}

# {{{ sub ModifyPermitted 
sub ModifyPermitted  {
  my $self = shift;
  #TODO: Implement
  return(1);
}
# }}}

1;
 
