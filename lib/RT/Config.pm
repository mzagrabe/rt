package RT::Config;

use strict;
use warnings;

=head1 NAME

    RT::Config - RT's config

=head1 SYNOPSYS

    # get config object
    use RT::Config;
    my $config = new RT::Config;
    $config->LoadConfigs;

    # get or set option
    my $rt_web_path = $config->Get('WebPath');
    $config->Set(EmailOutputEncoding => 'latin1');

    # get config object from RT package
    use RT;
    RT->LoadConfig;
    my $config = RT->Config;

=head1 DESCRIPTION

C<RT::Config> class provide access to RT's and RT extensions' config files.

RT uses two files for site configuring:

First file is F<RT_Config.pm> - core config file. This file is shipped
with RT distribution and contains default values for all available options.
B<You should never edit this file.>

Second file is F<RT_SiteConfig.pm> - site config file. You can use it
to customize your RT instance. In this file you can override any option
listed in core config file.

RT extensions could also provide thier config files. Extensions should
use F<< <NAME>_Config.pm >> and F<< <NAME>_SiteConfig.pm >> names for
config files, where <NAME> is extension name.

B<NOTE>: All options from RT's config and extensions' configs are saved
in one place and thus extension could override RT's options, but it is not
recommended.

=cut

my %META = ();
my %OPTIONS = ();

=head1 METHODS

=head2 new

Object constructor returns new object. Takes no arguments.

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto)? ref($proto): $proto;
    my $self = bless {}, $class;
    $self->_Init(@_);
    return $self;
}

sub _Init
{
    return;
}

=head2 LoadConfigs

Load all configs. First of all load RT's config then load config files
of the extensions in alphabetic order.
Takes nothing.

=cut

sub LoadConfigs
{
    my $self = shift;
    my @configs = $self->Configs;
    $self->LoadConfig( File => $_ ) foreach @configs;
    return;
}

=head1 LoadConfig

Takes param hash with C<File> field.
First, the site configuration file is loaded, in order to establish
overall site settings like hostname and name of RT instance.
Then, the core configuration file is loaded to set fallback values
for all settings; it bases some values on settings from the site
configuration file.

B<Note> that core config file don't change options if site config
has set them so to add value to some option instead of
overriding you have to copy original value from core config file.

=cut

sub LoadConfig
{
    my $self = shift;
    my %args = (File => '', @_);
    $args{'File'} =~ s/(?<!Site)(?=Config\.pm$)/Site/;
    $self->_LoadConfig( %args );
    $args{'File'} =~ s/Site(?=Config\.pm$)//;
    $self->_LoadConfig( %args );
    return 1;
}

sub _LoadConfig
{
    my $self = shift;
    my %args = (File => '', @_);

    my $is_ext = $args{'File'} !~ /^RT_(?:Site)?Config/? 1: 0;
    my $is_site = $args{'File'} =~ /SiteConfig/? 1: 0;

    eval {
        package RT;
        local *Set = sub(\[$@%]@) {
            my ($opt_ref, @args) = @_;
            my ($pack, $file, $line) = caller;
            return $self->SetFromConfig(
                Option     => $opt_ref,
                Value      => [@args],
                Package    => $pack,
                File       => $file,
                Line       => $line,
                SiteConfig => $is_site,
                Extension  => $is_ext,
            );
        };
        local @INC = ($LocalEtcPath, $EtcPath);
        require $args{'File'};
    };
    if( $@ ) {
        return 1 if $is_site && $@ =~ qr{^Can't locate \Q$args{File}};
        die ("Couldn't load config file '$args{File}': $@");
    }
    return 1;
}

=head2 Configs

Returns list of the configs file names.
F<RT_Config.pm> is always first, other configs are ordered by name.

=cut

sub Configs
{
    my $self = shift;
    my @configs = ();
    foreach my $path( $RT::LocalEtcPath, $RT::EtcPath ) {
        my $mask = File::Spec->catfile($path, "*_Config.pm");
        my @files = glob $mask;
        @files = grep { $_ !~ /^RT_Config\.pm$/ }
                 grep { $_ && /^\w+_Config\.pm$/ }
             map { s/^.*[\\\/]//; $_ } @files;
        push @configs, @files;
    }

    @configs = sort @configs;
    unshift(@configs, 'RT_Config.pm');

    return @configs;
}

=head2 Get

Takes name of the option as argument and returns its current value.

=cut

sub Get
{
    my $self = shift;
    my $name = shift;
    my $type = $META{$name}->{'Type'} || 'SCALAR';
    if( $type eq 'ARRAY' ) {
        return @{ $OPTIONS{$name} };
    } elsif( $type eq 'HASH' ) {
        return %{ $OPTIONS{$name} };
    }
    return $OPTIONS{$name};
}

=head2 Set

Takes two arguments: name of the option and new value.
Set option's value to new value.

=cut

sub Set
{
    my $self = shift;
    my $name = shift;

    my $type = $META{$name}->{'Type'} || 'SCALAR';
    if( $type eq 'ARRAY' ) {
        $OPTIONS{$name} = [ @_ ];
    } elsif( $type eq 'HASH' ) {
        $OPTIONS{$name} = { @_ };
    } else {
        $OPTIONS{$name} = shift;
    }
    $META{$name}->{'Type'} = $type;

    return 1;
}

sub SetFromConfig
{
    my $self = shift;
    my %args = (
        Option => undef,
        Value => [],
        Package => 'RT',
        File => '',
        Line => 0,
        SiteConfig => 1,
        Extension => 0,
        @_
    );

    unless( $args{'File'} ) {
        ($args{'Package'},$args{'File'},$args{'Line'}) = caller(1);
    }

    my $opt = $args{'Option'};
    my $type;
    my $name = $self->__GetNameByRef( $opt );
    if( $name ) {
        $type = ref $opt;
        $name =~ s/.*:://;
    } else {
        $type = $META{$name}->{'Type'} || 'SCALAR';
        $name = $$opt;
    }

    return 1 if exists $OPTIONS{$name} && !$args{'SiteConfig'};

    $META{$name}->{'Type'} = $type;
    $self->Set( $name, @{ $args{'Value'} } );
    
    return 1;
}

sub __GetNameByRef
{
    my $self = shift;
    my $ref = shift;
    my $pack = shift || 'main::';
    $pack .= '::' unless $pack =~ /::$/;
    my %ref_sym = (
        SCALAR => '$',
        ARRAY => '@',
        HASH => '%',
        CODE => '&',
    );
    no strict 'refs';
    my $name = undef;
    # scan $pack name table(hash)
    foreach my $k( keys %{$pack} ) {
        # hash for main:: has reference on itself
        next if $k eq 'main::';

        # if entry has trailing '::' then
        # it is link to other name space
        if( $k =~ /::$/ ) {
            $name = $self->__GetNameByRef($ref, $k);
            return $name if $name;
        }

        # entry of the table with references to
        # SCALAR, ARRAY... and other types with
        # the same name
        my $entry = ${$pack}{$k};

        # get entry for type we are looking for
        my $entry_ref = *{$entry}{ref($ref)};
        next unless $entry_ref;

        # if references are equal then we've found
        if( $entry_ref == $ref ) {
            return ($ref_sym{ref($ref)} || '*') . $pack . $k;
        }
    }
    return '';
}

1;
