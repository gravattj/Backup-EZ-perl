#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use Backup::EZ;
use Data::Dumper;
use Test::More;
use File::Slurp;
use Data::Printer alias => 'pdump';
use File::Path;
use File::RandomGenerator;

require "t/common.pl";

use constant SRC_DIR     => '/tmp/backup_ez_testdata';
use constant FOO_SUBDIR  => 'dir1/foo';
use constant SRC_FOO_DIR => sprintf( '%s/%s', SRC_DIR(), FOO_SUBDIR() );

###### NUKE AND PAVE ######

nuke();
pave();

###### RUN TESTS ######

my $ez = Backup::EZ->new(
    conf         => 't/ezbackup_chunked.conf',
    exclude_file => 'share/ezbackup_exclude.rsync',
    dryrun       => 0
);
die if !$ez;
remove_tree($ez->get_dest_dir);

validate_conf($ez);
finish_paving($ez);
ok( $ez->backup );

my @list = $ez->get_list_of_backups();
ok( @list == 1 );

my $foo_subdir = get_dest_foo_dir( $ez, $list[0] );
ok( -d $foo_subdir, "checking that $foo_subdir does exist" );

# check counts
my $src_count  = get_dir_entry_count(SRC_DIR);
my $dest_count = get_dir_entry_count( get_dest_backup_dir($ez, $list[0]) );
ok( $src_count == $dest_count, "checking file counts" );

#
# now do an inc backup
#
sleep 1;
ok($ez->backup());
@list = $ez->get_list_of_backups();
ok( @list == 2 );

$foo_subdir = get_dest_foo_dir( $ez, $list[1] );
ok( -d $foo_subdir, "checking that $foo_subdir does exist" );

# check counts
$src_count  = get_dir_entry_count(SRC_DIR);
$dest_count = get_dir_entry_count( get_dest_backup_dir($ez, $list[1]) );
ok( $src_count == $dest_count, "checking file counts" );

done_testing();
nuke();

#######################

sub get_dir_entry_count {

    my $dir = shift;

    my @files = `find $dir -type f`;

    return scalar(@files);
}

sub finish_paving {
    my $ez = shift;

    my $src_foo = SRC_FOO_DIR;

    my $frg = File::RandomGenerator->new(
        root_dir => $src_foo,
        unlink   => 0,
        depth    => 2
    );
    $frg->generate;
    $frg->generate;

    my @out = `find $src_foo`;
    if ( @out < 2 ) {
        die "not enough files in $src_foo";
    }
}

sub get_dest_foo_dir {
    my $ez         = shift;
    my $backup = shift;

    my $foo_dir = sprintf(
        '%s/%s%s',
        $ez->get_dest_dir, #
        $backup,             #
        SRC_FOO_DIR(), #
    );

    return $foo_dir;
}

sub get_dest_backup_dir {
    my $ez = shift;
    my $backup = shift;
    
    my $dir =  sprintf( '%s/%s', get_root_backup_dir($ez, $backup), SRC_DIR() );
    
    return $dir;
}

sub get_root_backup_dir {
    my $ez = shift;
    my $backup = shift;
    
    return sprintf( '%s/%s', $ez->get_dest_dir, $backup );
}

sub validate_conf {
    my $ez = shift;

    # should only have one source dir
    my @dirs = $ez->get_conf_dirs;
    if ( scalar @dirs == 2 ) {
        return 1;
    }

    die "expected 2 dir stanzas";
}
