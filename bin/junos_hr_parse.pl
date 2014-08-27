#!/usr/bin/perl

use strict;
use Data::Dumper;
my $struct = {};
my $cur_struct = \$struct;
my @stack = ();
my $cur_key;
my $port_map = {};

my $services;
if( open( $services, '</etc/services' )){
	while(<$services>){
		s/^\s+|\s+$//g;
		s/\s*#.*//g;
		next unless $_;
		if( m{^(\S+)\s+([^/]+)/.*$} ){
			$port_map->{$1} = $2;
		}
		elsif( !m{^[^/]+/.*$} ){
			warn "Unknown line in /etc/services ".$_;
		}
	}
}
else {
	warn "Unable to open /etc/services. Port mapping disabled. ".$!;
}

while(<>){
	s/^\s+|\s+$//g;
	s/\s*#.*//g;
	next unless $_;
	if( /^(.*?)\s*{$/ ){
		$cur_key = $1;
		push @stack, $cur_struct;
		my $new_val = {};
		${$cur_struct}->{$cur_key} = $new_val;
		$cur_struct = \$new_val;
	}
	elsif( /^(\S+);$/ ){
		unless(ref $$cur_struct eq 'ARRAY') {
			$cur_struct = $stack[$#stack];
			my $new_val = [];
			${$cur_struct}->{$cur_key} = $new_val;
			$cur_struct = \$new_val;
		}
		my $val = $1;
		if( $cur_key =~ /\-port/ && $val !~ /^\d+$/){
			$val = $port_map->{$val} if exists $port_map->{$val};
		}
		push @$$cur_struct, $val; 
	}
	elsif( /^(\S+)\s(\S+);$/ ){
		my $key = $1;
		my $val = $2;
		if( $key =~ /\-port/ && $val !~ /^\d+$/){
			$val = $port_map->{$val} if exists $port_map->{$val};
		}
		${$cur_struct}->{$key} = [$val];
	}
	elsif( /^}$/ ){
		$cur_struct = pop @stack;
	}
	elsif( /^(.*)\s+\[\s*([^]]+)\s*\];$/ ){
		my $key = $1;
		${$cur_struct}->{$key} = [map {$key =~ /-port/ && $_ !~ /^\d+$/ && exists $port_map->{$_} ? $port_map->{$_} : $_} split(/\s+/, $2)];
	}
	else {
		die "Unknown line: ".$_;
	}
}

print Dumper( $struct );

