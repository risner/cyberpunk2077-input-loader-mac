#!/usr/bin/perl
use FindBin;
use File::Path qw(make_path);
use XML::LibXML;
use File::Find;
use Data::Dumper;
use strict;
use warnings;

my $MOD_VERSION_STR = "1.0";

sub LoadXML {
  my $xmlfile = shift(@_);

  # Load the User Mappins XML document
  my $parser = XML::LibXML->new(
     keep_blanks => 0,	# retain blanks and whitespace nodes
     no_blanks   => 0,
     load_ext_dtd => 0	# do not load a DTD
  );
  my $loaded = eval {
    $parser->parse_file($xmlfile);
  };

  if ($@) {
    print "Error parsing '$xmlfile':\n$@";
      exit 0;
  }

  # Find and remove comment nodes
  foreach my $comment ($loaded->findnodes('//comment()')) {
    $comment->parentNode->removeChild($comment);
  }
  
  return $loaded;
}


sub MergeDocument {

  my $path = shift(@_);
  my $inputContextsOriginal = shift(@_);
  my $inputUserMappingsOriginal = shift(@_);

  my %valid_inputUserMappings = (
    "mapping"		=> 1,
    "buttonGroup"	=> 1,
    "pairedAxes"	=> 1,
    "preset"		=> 1
  );


  my %valid_inputContexts = (
    "blend"		=> 1,
    "context"		=> 1,
    "hold"		=> 1,
    "multitap"		=> 1,
    "repeat"		=> 1,
    "toggle"		=> 1,
    "acceptedEvents"	=> 1
  );

  # inputUserMappings.xml bindings children:
  # * mapping
  # * buttonGroup
  # * pairedAxes
  # * preset

  # inputContexts.xml bindings children:
  # * blend
  # * context
  # * hold
  # * multitap
  # * repeat
  # * toggle
  # * acceptedEvents

  # uiInputActions.xml input_actions children:
  # * filter

  # inputDeadzones.xml deadzones children:
  # * radialDeadzone
  # * angularDeadzone

  my $modDocument = LoadXML($path);
  my $document = undef;

  print "Loading document: $path\n";

  for my $modNode ($modDocument->findnodes('/bindings/*')) {
    my ($existing) = undef;

    # e.g. context
    my $tag = $modNode->nodeName;

    $document = undef;

    print("* Processing mod input block: $tag\n");

    if (exists($valid_inputContexts{$tag})) {

      my $name = $modNode->getAttribute('name');
      if (defined($name)) {
        # Search for <bindings>/<tag>[@name="$name"]
        # print("findnodes(" . '/bindings/' . $tag . '[@name="' . $name . '"]' . ")\n");
        ($existing) = $inputContextsOriginal->findnodes(
          '/bindings/' . $tag . '[@name="' . $name . '"]'
        );
        if (defined($existing)) {
          # print("Tag: $tag Name: $name found existing " . $existing->nodeName . " using inputContextsOriginal\n");
        } else {
          # print("Tag: $tag Name: $name using inputContextsOriginal\n");
        }
      } else {
        # print("Tag: $tag Name:  using inputContextsOriginal\n");
      }
      $document = $inputContextsOriginal;


    } elsif (exists($valid_inputUserMappings{$tag})) {

      my $name = $modNode->getAttribute('name');
      if (defined($name)) {
        # Search for <bindings>/<tag>[@name="$name"]
        # print("findnodes(" . '/bindings/' . $tag . '[@name="' . $name . '"]' . ")\n");
        ($existing) = $inputUserMappingsOriginal->findnodes(
          '/bindings/' . $tag . '[@name="' . $name . '"]'
        );
        if (defined($existing)) {
          # print("Tag: $tag Name: $name found existing " . $existing->nodeName . " using inputUserMappingsOriginal\n");
        } else {
          # print("Tag: $tag Name: $name using inputUserMappingsOriginal\n");
        }
      } else {
        # print("Tag: $tag Name:  using inputUserMappingsOriginal\n");
      }
      $document = $inputUserMappingsOriginal;

    } else {
      print("* <bindings> child $tag not valid\n");
      continue;
    }

    # $existing came from one of the original files
    if (defined($existing)) {
      # print "Found: ", $existing->toString, "\n";
      if ($modNode->getAttribute('append') && $modNode->getAttribute('append') eq 'true') {
        # Append to desired document
        for my $modNodeChild ($modNode->childNodes) {
          # Must be an element
          next unless $modNodeChild->nodeType == XML_ELEMENT_NODE;

          # Append it, making a clone first
          my $clone = $modNodeChild->cloneNode(1);
          $existing->appendChild($clone);
        }
      } else {
        # Replace existing node inside <bindings>
        # TODO This is broken, uses undefined $document
        my ($bindings) = $document->findnodes('/bindings/*');
        if ($bindings) {
          $bindings->removeChild($existing);
          my $clone = $modNode->cloneNode(1);
          $bindings->appendChild($clone);
        }
      }
    } else {
      # Replace existing node inside <bindings>
      my ($bindings) = $document->findnodes('/bindings');
      if ($bindings) {
        my $clone = $modNode->cloneNode(1);
        $bindings->appendChild($clone);
      }
    }
  }
}

print("Starting up Input Loader\n");

# What is the path to this script?
my $gameDir = "$FindBin::Bin/$FindBin::Script";

# Assuming we are correctly formatted, go to the gameDir.
if ($gameDir =~ /engine\/tools\/inputloader\.pl$/) {
  $gameDir =~ s/engine\/tools\/inputloader\.pl//;
} else {
  print "Failed to find the gameDir, running from $gameDir\n";
  exit(0);
}

# Make the path, if it doesn't exist.
my $inputDir = $gameDir . "r6/input";
if (! -d "$inputDir") {
  make_path($inputDir);
}

print("Loading original input configs for merging\n");

# Load the Context XML document
# The mac version has two files, using the one with '_mac' in the name.
# r6/config/inputContexts_mac.xml
my $inputContextsOriginal = LoadXML("r6/config/inputContexts_mac.xml");

# Load the User Mappins XML document
my $inputUserMappingsOriginal = LoadXML("r6/config/inputUserMappings.xml");

print("Loading input configs from r6/input\n");

find(
    sub {
        return unless -f $_;            # no directories
        return unless /\.xml$/i;        # .xml (case-insensitive)
        my $path = $File::Find::name;
        MergeDocument($path, $inputContextsOriginal, $inputUserMappingsOriginal);
    },
    $inputDir
);

print("Loading input configs from dynamically added paths - unsupported on macOS at this time\n");

# save files
$inputContextsOriginal->toFile($gameDir . "r6/cache/inputContexts.xml", 0);
print("Merged inputContexts saved to 'r6/cache/inputContexts.xml'\n");

$inputUserMappingsOriginal->toFile($gameDir . "r6/cache/inputUserMappings.xml", 0);
print("Merged inputUserMappings saved to 'r6/cache/inputUserMappings.xml'\n");

=pod

Reimplementation of Jack Humbert's
https://github.com/jackhumbert/cyberpunk2077-input-loader

=cut
