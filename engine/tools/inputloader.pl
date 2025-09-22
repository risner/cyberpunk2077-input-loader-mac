#!/usr/bin/perl
use FindBin;
use File::Path qw(make_path);
use XML::LibXML;
use File::Find;
use Data::Dumper;
use strict;
use warnings;

my $MOD_VERSION_STR = "0.1.1";

sub LoadXML {
  my $xmlfile = shift(@_);

  # Load the User Mappins XML document
  my $parser = XML::LibXML->new(
    keep_blanks => 1,	# retain blanks and whitespace nodes
    no_blanks   => 0,
    load_ext_dtd => 0	# do not load a DTD
  );
  my $loaded = eval {
    $parser->parse_file($xmlfile);
  };

  if ($@) {
    print "Error parsing '$xmlfile':\n$@";
      exit 0;
  } else {
    print "Loaded $xmlfile\n";
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

  print "Loading document: : $path\n";

  my ($existing);

  for my $modNode ($modDocument->findnodes('/bindings/*')) {
    my $tag = $modNode->nodeName;

    my $name = $modNode->getAttribute('name');
    print("* Processing mod input block: $name\n");

    if (exists($valid_inputUserMappings{$tag})) {

      # Search for <bindings>/<tag>[@name="$name"]
      #($existing) = $inputContextsOriginal->findnodes(
      #  qq{/bindings/$tag[@name="$name"]}
      #);
      $document = $inputContextsOriginal;

    } elsif (exists($valid_inputContexts{$tag})) {

      # Search for <bindings>/<tag>[@name="$name"]
      #($existing) = $inputUserMappingsOriginal->findnodes(
      #  qq{/bindings/$tag[\@name="$name"]}
      #);
      $document = $inputUserMappingsOriginal;

    } else {
      print("* <bindings> child $name not valid\n");
      continue;
    }

    # $existing came from one of the original files
    if (defined($existing)) {
      print "Found: ", $existing->toString, "\n";
      print(Dumper($modNode));
      print(Dumper($tag));
      print(Dumper($name));
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
        my ($bindings) = $document->findnodes('/bindings');
        print(Dumper($bindings));
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

print("Starting up input_loader $MOD_VERSION_STR\n");

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
