#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
    unless (@ARGV == 1) {
        die "Usage: spider.pl <Oligonychus_installation_directory>.\n";
    }
    my $home = shift @ARGV;
    unless (-e $home && -d $home) {
        die "The argument $home does not exists or is not a directory.\n";
    }
    unshift @INC, "$home/lib"; 
    unshift @INC, "$home/conf"; 
    $ENV{OLIGONYCHUS_HOME} = $home;
}

use TvgagaConf qw($config $bot_conf);
use AzriSpider;
use ParserFactory;
use PostTaskFactory;
use TVGagaLoader;

# Get list of URL to spider, call AzriSpider::spider
foreach my $channel ( keys( %{$config} ) ) {
	print "Spidering $config->{$channel}->{'schedules_url'} scheules URL for $channel \n";

	my $sets = [ { qstr => '', outf => '', args => [], } ];
	if ( ref( $config->{$channel}->{'get_params'} ) eq 'CODE' ) {
		$sets = $config->{$channel}->{'get_params'}->();
	}

	foreach my $set ( @{$sets} ) {

		my $content = '';
		# spider the  URL
		my $err = AzriSpider::spider(
			config => $bot_conf,
			url => $config->{$channel}->{'schedules_url'} . $set->{'qstr'},
			content => \$content,
		);

		if ( $err ) {
			print "Error spidering $channel : ", $content, "\n";
			next;
		}

		my $out_file = $config->{$channel}->{'schedules_csv'};
		if ( $set->{'outf'} ) {
			$out_file = $set->{'outf'} . $config->{$channel}->{'schedules_csv'};
		}

		# Get a parser object from ParserFactory
		my $parser = ParserFactory::get_parser(
			channel => $channel,
			schedules_csv => "$ENV{OLIGONYCHUS_HOME}/data/" . $out_file,
			args => $set->{'args'},
		);
		$parser->isa('HTML::Parser') or die "Parser factory error!\n";

		# pass content to appropriate site parser module
		$parser->parse( $content );
		$parser->eof;

		$parser->done();

		next if ( @{[stat("$ENV{OLIGONYCHUS_HOME}/data/$out_file")]}[7] < 15 );

		# Get a Post Parsing task object from PostTaskFactory
		my $posttask = PostTaskFactory::get_posttask(
			channel => $channel,
			schedules_csv => "$ENV{OLIGONYCHUS_HOME}/data/" . $out_file,
		);
		$posttask->isa('AzTask::TaskBase') or die "PostTask factory error!\n";

		$posttask->do();
		$posttask->done();
	}
}
