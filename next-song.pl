#!/usr/bin/perl

use strict;
use warnings;

use Pod::Usage;
use Getopt::Long qw(GetOptions);
use File::Find::Rule;
use DBI;
use MP3::Info;
use File::Basename;
use File::Slurper 'write_text';

my %opt;

GetOptions(
	'i|init=s' => \$opt{i},
	'h|help' => \$opt{h},
);

my $dbfile = '/tmp/music.sql3';
my $jsonfile = '/home/www/radio/song.json'
my $dsn      = "dbi:SQLite:dbname=$dbfile";

if( ! -f $dbfile){

	my $dbh = DBI->connect($dsn, "", "", {
		 PrintError       => 0,
		 RaiseError       => 1,
		 AutoCommit       => 1,
		 FetchHashKeyName => 'NAME_lc',
	});

my $sql = <<'SCHEMA';
CREATE TABLE music (
   path TEXT PRIMARY KEY,
   count INTEGER DEFAULT 0
);
SCHEMA

	$dbh->do($sql);
	$dbh->disconnect;
}

if($opt{h}){
	pod2usage(-verbose => 2, -output => '-');
	exit;
}

my $dbh = DBI->connect($dsn, "", "", {
	 PrintError       => 0,
	 RaiseError       => 1,
	 AutoCommit       => 1,
	 FetchHashKeyName => 'NAME_lc',
});

if($opt{i}){
	$dbh->do("DELETE FROM music");

	my @files = File::Find::Rule->file()
	->name( "*.mp3" )
	->nonempty()
	->in( $opt{i} );

	$dbh->do("PRAGMA synchronous = OFF");

	foreach my $path (@files){
				$dbh->do("INSERT INTO music (path,count) VALUES ('$path', 0)");
	}

	$dbh->disconnect;
	exit;
}

my $sql = 'SELECT min(count) FROM music;';
my $sth = $dbh->prepare($sql);
$sth->execute();

my @row = $sth->fetchrow_array;
my $min = $row[0];

$sql = 'SELECT path FROM music WHERE count = ? ORDER BY RANDOM() LIMIT 1;';
$sth = $dbh->prepare($sql);
$sth->execute($min);

@row = $sth->fetchrow_array;
my $file = $row[0];
my $dir = dirname($file);
my $cover = '/cover.png';

if( -f "$dir/cover.jpg"){
	$cover = "$dir/cover.jpg";
	$cover =~ s/\/home\/data\/mp3\//\/covers\//;
}

$dbh->do('UPDATE music SET count = count + 1 WHERE path = ?', undef, $file);

my $tag = get_mp3tag($file);

write_text($jsonfile, sprintf ('{"artist":"%s","album":"%s","song":"%s","cover":"%s"}',
 	     $tag->{'ARTIST'},
 	     $tag->{'ALBUM'},
 	     $tag->{'TITLE'},
			 $cover
		 )
);

print "$file\n";

__END__

=head1 SYNOPSIS

next-song.pl [OPTIONS]

=head1 OPTIONS AND ARGUMENTS

	 -i, --init /paht/to/mp3/files
			Initialize song database

	 -h, --help
			Show help

=cut
