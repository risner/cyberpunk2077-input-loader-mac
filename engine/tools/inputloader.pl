#!/usr/bin/perl
use FindBin;
use File::Path qw(make_path);
use XML::LibXML;
use File::Find;
use Data::Dumper;
use strict;
use warnings;

my $MOD_VERSION_STR = "1.1";

sub LoadXML {
  my $xmlfile = shift(@_);

  print "[InputLoader] Loading XML: $xmlfile\n";

  # Load the User Mappings / Contexts XML document
  my $parser = XML::LibXML->new(
     keep_blanks  => 0,	# retain blanks and whitespace nodes
     no_blanks    => 0,
     load_ext_dtd => 0	# do not load a DTD
  );
  my $loaded = eval {
    $parser->parse_file($xmlfile);
  };

  if ($@) {
    print "[InputLoader] ERROR parsing '$xmlfile':\n$@\n";
    return undef;
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
  if (!defined($modDocument)) {
    print "[InputLoader] Skipping mod file due to previous XML error: $path\n";
    return;
  }

  my $document = undef;

  print "[InputLoader] Loading mod document for merge: $path\n";

  for my $modNode ($modDocument->findnodes('/bindings/*')) {
    my ($existing) = undef;

    # e.g. context
    my $tag = $modNode->nodeName;

    $document = undef;

    print("[InputLoader] * Processing mod input block: $tag\n");

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
      print("[InputLoader] * WARNING: <bindings> child '$tag' not valid, skipping.\n");
      next;
    }

    # $existing came from one of the original files
    if (defined($existing)) {
      my $name = $modNode->getAttribute('name');
      my $append_flag = $modNode->getAttribute('append');
      print "[InputLoader]   Found existing '$tag' block" . (defined($name) ? " with name '$name'" : "") . " (append=" . (defined($append_flag) ? $append_flag : 'false') . ")\n";

      if ($modNode->getAttribute('append') && $modNode->getAttribute('append') eq 'true') {
        # Append to desired document
        for my $modNodeChild ($modNode->childNodes) {
          # Must be an element
          next unless $modNodeChild->nodeType == XML_ELEMENT_NODE;

          # Append it, making a clone first
          my $clone = $modNodeChild->cloneNode(1);
          $existing->appendChild($clone);
        }
        print "[InputLoader]   Appended children to existing '$tag' block" . (defined($name) ? " ('$name')" : "") . "\n";
      } else {
        # Replace existing node inside <bindings>
        my ($bindings) = $document->findnodes('/bindings');
        if ($bindings) {
          $bindings->removeChild($existing);
          my $clone = $modNode->cloneNode(1);
          $bindings->appendChild($clone);
          print "[InputLoader]   Replaced existing '$tag' block" . (defined($name) ? " ('$name')" : "") . "\n";
        } else {
          print "[InputLoader]   WARNING: couldn't find <bindings> root while replacing existing '$tag' block\n";
        }
      }
    } else {
      # No existing node: append inside <bindings>
      my ($bindings) = $document->findnodes('/bindings');
      if ($bindings) {
        my $clone = $modNode->cloneNode(1);
        $bindings->appendChild($clone);
        my $name = $modNode->getAttribute('name');
        print "[InputLoader]   Added new '$tag' block" . (defined($name) ? " ('$name')" : "") . " to bindings\n";
      } else {
        print "[InputLoader]   WARNING: couldn't find <bindings> root while adding new '$tag' block\n";
      }
    }
  }
}

print("[InputLoader] Starting up Input Loader (version $MOD_VERSION_STR)\n");

# What is the path to this script?
my $gameDir = "$FindBin::Bin/$FindBin::Script";

# Assuming we are correctly formatted, derive the gameDir from this script's path.
if ($gameDir =~ /engine\/tools\/inputloader\.pl$/) {
  $gameDir =~ s/engine\/tools\/inputloader\.pl//;
  print "[InputLoader] Resolved gameDir to: $gameDir\n";
} else {
  print "[InputLoader] ERROR: Failed to find the gameDir, running from $gameDir\n";
  exit(0);
}

# Make the path, if it doesn't exist.
my $inputDir = $gameDir . "r6/input";
if (! -d "$inputDir") {
  print "[InputLoader] Creating input directory: $inputDir\n";
  make_path($inputDir);
}

print("[InputLoader] Loading original input configs for merging\n");

# Load the Context XML document
# The mac version has two files, using the one with '_mac' in the name.
# r6/config/inputContexts_mac.xml
my $inputContextsOriginal = LoadXML($gameDir . "r6/config/inputContexts_mac.xml");
if (!defined($inputContextsOriginal)) {
  print "[InputLoader] FATAL: Failed to load inputContexts_mac.xml, aborting.\n";
  exit(0);
}

# Load the User Mappings XML document
my $inputUserMappingsOriginal = LoadXML($gameDir . "r6/config/inputUserMappings.xml");
if (!defined($inputUserMappingsOriginal)) {
  print "[InputLoader] FATAL: Failed to load inputUserMappings.xml, aborting.\n";
  exit(0);
}

print("[InputLoader] Scanning for input mod XMLs under: $inputDir\n");

my $mod_file_count = 0;
find(
    sub {
        return unless -f $_;            # no directories
        return unless /\.xml$/i;       # .xml (case-insensitive)
        my $path = $File::Find::name;
        print "[InputLoader] Discovered mod input file: $path\n";
        $mod_file_count++;
        MergeDocument($path, $inputContextsOriginal, $inputUserMappingsOriginal);
    },
    $inputDir
);

if ($mod_file_count == 0) {
    print "[InputLoader] No mod input XML files found in $inputDir (this can be normal).\n";
}

print("[InputLoader] Loading input configs from dynamically added paths - unsupported on macOS at this time\n");

# save files
$inputContextsOriginal->toFile($gameDir . "r6/cache/inputContexts.xml", 0);
print("[InputLoader] Merged inputContexts saved to '" . $gameDir . "r6/cache/inputContexts.xml'\n");

$inputUserMappingsOriginal->toFile($gameDir . "r6/cache/inputUserMappings.xml", 0);
print("[InputLoader] Merged inputUserMappings saved to '" . $gameDir . "r6/cache/inputUserMappings.xml'\n");

=pod

Reimplementation of Jack Humbert's
https://github.com/jackhumbert/cyberpunk2077-input-loader

=cut
