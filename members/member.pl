#!/usr/bin/perl


#script to do a borrower enquiry/bring up borrower details etc
#written 20/12/99 by chris@katipo.co.nz


# Copyright 2000-2002 Katipo Communications
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

use strict;
use C4::Auth;
use C4::Output;
use CGI;
use C4::Members;


my $input = new CGI;
my $quicksearch = $input->param('quicksearch');
my $startfrom = $input->param('startfrom')||1;
my $resultsperpage = $input->param('resultsperpage')||C4::Context->preference("PatronsPerPage")||20;

my ($template, $loggedinuser, $cookie);
if($quicksearch){
    ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "members/member-quicksearch-results.tmpl",
                 query => $input,
                 type => "intranet",
                 authnotrequired => 0,
                 flagsrequired => {borrowers => '*'},
                 debug => 1,
                 });
} else {
    ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "members/member.tmpl",
                 query => $input,
                 type => "intranet",
                 authnotrequired => 0,
                 flagsrequired => {borrowers => '*'},
                 debug => 1,
                 });
}
my $theme = $input->param('theme') || "default";


$template->param( 
        "AddPatronLists_".C4::Context->preference("AddPatronLists")=> "1",
            );
if (C4::Context->preference("AddPatronLists")=~/code/){
    my $categories=GetBorrowercategoryList;
    $categories->[0]->{'first'}=1;
    $template->param(categories=>$categories);  
}  
            # only used if allowthemeoverride is set
#my %tmpldata = pathtotemplate ( template => 'member.tmpl', theme => $theme, language => 'fi' );
    # FIXME - Error-checking
#my $template = HTML::Template->new( filename => $tmpldata{'path'},
#                   die_on_bad_params => 0,
#                   loop_context_vars => 1 );

my $member = $input->param('member');
my $member_orig = $member;
my $orderby = $input->param('orderby');
my $searchfield = $input->param('searchfield');

$orderby = "surname,firstname" unless $orderby;
$member =~ s/,//g;   #remove any commas from search string
$member =~ s/\*/%/g;

my ($count,$results);

my $search_sql;
if ( $input->param('sqlsearch') ) {
  $resultsperpage = '1000';
  $search_sql = 'SELECT * FROM borrowers LEFT JOIN categories ON borrowers.categorycode = categories.categorycode WHERE ';
  my @parts = split( /;/, $input->param('sqlsearch') );
  $search_sql .= $parts[0];
  $template->param( member => $search_sql );
  ($count, $results) = SearchMemberBySQL( $search_sql );
}
elsif( $searchfield ) {
    ($count, $results)=SearchMemberField( $member, $orderby, $searchfield );
    $template->param( searchfield => $searchfield );
}
elsif(length($member) == 1)
{
    ($count,$results)=SearchMember($member,$orderby,"simple");
}
else
{
    ($count,$results)=SearchMember($member,$orderby,"advanced");
}


my @resultsdata;
my $to=($count>($startfrom*$resultsperpage)?$startfrom*$resultsperpage:$count);
for (my $i=($startfrom-1)*$resultsperpage; $i < $to; $i++){
  #find out stats
  my ($od,$issue,$fines)=GetMemberIssuesAndFines($results->[$i]{'borrowernumber'});

  my %row = (
    count => $i+1,
    borrowernumber => $results->[$i]{'borrowernumber'},
    cardnumber => $results->[$i]{'cardnumber'},
    PreviousCardnumber => $results->[$i]{'PreviousCardnumber'},
    surname => $results->[$i]{'surname'},
    firstname => $results->[$i]{'firstname'},
    initials => $results->[$i]{'initials'},
    categorycode => $results->[$i]{'categorycode'},
    category_type => $results->[$i]{'category_type'},
    category_description => $results->[$i]{'description'},
    address => $results->[$i]{'address'},
	address2 => $results->[$i]{'address2'},
    city => $results->[$i]{'city'},
	zipcode => $results->[$i]{'zipcode'},
	country => $results->[$i]{'country'},
    branchcode => $results->[$i]{'branchcode'},
    overdues => $od,
    issues => $issue,
    odissue => "$od/$issue",
    fines =>  sprintf("%.2f",$fines),
    borrowernotes => $results->[$i]{'borrowernotes'},
    sort1 => $results->[$i]{'sort1'},
    sort2 => $results->[$i]{'sort2'},
    dateexpiry => C4::Dates->new($results->[$i]{'dateexpiry'},'iso')->output('syspref'),
    );
  push(@resultsdata, \%row);
}
my $base_url =
    'member.pl?&amp;'
  . join(
    '&amp;',
    map { $_->{term} . '=' . $_->{val} } (
        { term => 'member', val => $member_orig},
        { term => 'orderby', val => $orderby },
        { term => 'resultsperpage', val => $resultsperpage },
        { term => 'type',           val => 'intranet' },
        { term => 'searchfield', val => $searchfield },
    )
  );

$template->param(
    paginationbar => pagination_bar(
        $base_url,  int( $count / $resultsperpage ) + 1,
        $startfrom, 'startfrom'
    ),
    startfrom => $startfrom,
    from      => ($startfrom-1)*$resultsperpage+1,  
    to        => $to,
    multipage => ($count != $to || $startfrom!=1),
);

$template->param( 
        searching       => "1",
        member          => $member_orig,
        numresults      => $count,
        resultsloop     => \@resultsdata,
            );

$template->param( ShowPatronSearchBySQL => C4::Context->preference('ShowPatronSearchBySQL') );

if ( $input->param('sqlsearch') ) {
  $template->param( member => $search_sql );
}
$template->param("showinitials" => C4::Context->preference('DisplayInitials'));

output_html_with_http_headers $input, $cookie, $template->output;
