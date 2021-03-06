#!/usr/bin/perl -w

use strict;
use XML::Twig;

sub write_c_header(@);
sub write_c_impl_defaults(@);
sub write_c_impl_apply(@);
sub write_c_impl_free(@);
sub write_c_impl_dump(@);
sub get_data($);

# initialize parser and read the file
my $input = "./config.xml";
my $parser = XML::Twig->new();
my $tree = $parser->parsefile($input) || die "Unable to parse XML file.";

# Write header file
open GENHEAD, ">gen_config.h" || die "Unable to write header file";
print GENHEAD "/* THIS FILE IS AUTOGENERATED - DO NOT CHANGE IT! */\n\nstruct hub_config\n{\n";
foreach my $p ($tree->root->children("option"))
{
	write_c_header(get_data($p));
}
print GENHEAD "};\n\n";

# Write c source file
open GENIMPL, ">gen_config.c" || die "Unable to write source file";
print GENIMPL "/* THIS FILE IS AUTOGENERATED - DO NOT CHANGE IT! */\n\n";

# The defaults function
print GENIMPL "void config_defaults(struct hub_config* config)\n{\n";
foreach my $p ($tree->root->children("option"))
{
	write_c_impl_defaults(get_data($p));
}
print GENIMPL "}\n\n";

# apply function
print GENIMPL "static int apply_config(struct hub_config* config, char* key, char* data, int line_count)\n{\n\tint max = 0;\n\tint min = 0;\n\n";

foreach my $p ($tree->root->children("option"))
{
	write_c_impl_apply(get_data($p));
}
print GENIMPL "\t/* Still here -- unknown directive */\n";
print GENIMPL "\tLOG_ERROR(\"Unknown configuration directive: '%s'\", key);\n";
print GENIMPL "\t\treturn -1;\n";
print GENIMPL "}\n\n";

# free function (for strings)
print GENIMPL "void free_config(struct hub_config* config)\n{\n";
foreach my $p ($tree->root->children("option"))
{
	write_c_impl_free(get_data($p));
}
print GENIMPL "}\n\n";

# dump function
print GENIMPL "void dump_config(struct hub_config* config, int ignore_defaults)\n{\n";
foreach my $p ($tree->root->children("option"))
{
	write_c_impl_dump(get_data($p));
}
print GENIMPL "}\n\n";



sub write_c_header(@)
{
	my @output = @_;
	my ($type, $name, $default, $advanced, $short, $desc, $since, $example) = @output;

	print GENHEAD "\t";
	print GENHEAD "int  " if ($type eq "int");
	print GENHEAD "int  " if ($type eq "boolean");
	print GENHEAD "char*" if ($type =~ /(string|file|message)/);
	print GENHEAD " " . $name . ";";

	my $comment = "";
	if ($type eq "message")
	{
		$comment = "\"" . $default . "\"";
	}
	elsif (defined $short && length $short > 0)
	{
		$comment = $short;
		$comment .= " (default: " . $default . ")" if (defined $default);
	}

	if (length $comment > 0)
	{
		my $pad = "";
		for (my $i = length $name; $i < 32; $i++)
		{
			$pad .= " ";
		}
		$comment = $pad . "/*<<< " . $comment . " */";
	}

	print GENHEAD $comment . "\n";
}

sub write_c_impl_defaults(@)
{
	my @output = @_;
	my ($type, $name, $default, $advanced, $short, $desc, $since, $example) = @output;
	my $prefix = "";
	my $suffix = "";

	print GENIMPL "\tconfig->$name = ";
	if ($type =~ /(string|file|message)/)
	{
		$prefix = "hub_strdup(\"";
		$suffix = "\")"
	}
	print GENIMPL $prefix . $default . $suffix . ";\n";
}

sub write_c_impl_apply(@)
{
	my @output = @_;
	my ($type, $name, $default, $advanced, $short, $desc, $since, $example, $p) = @output;

	my $min;
	my $max;
	my $regexp;

	if (defined $p)
	{
		$min = $p->att("min");
		$max = $p->att("max");
		$regexp = $p->att("regexp");

		print "'check' is defined for option $name";
		print ", min=$min" if (defined $min);
		print ", max=$max" if (defined $max);
		print ", regexp=\"$regexp\"" if (defined $regexp);
		print "\n";
	}

	print GENIMPL "\tif (!strcmp(key, \"" . $name . "\"))\n\t{\n";

	if ($type eq "int")
	{
		if (defined $min)
		{
			print GENIMPL "\t\tmin = $min;\n"
		}
		if (defined $max)
		{
			print GENIMPL "\t\tmax = $max;\n"
		}

		print GENIMPL "\t\tif (!apply_integer(key, data, &config->$name, ";

		if (defined $min)
		{
			print GENIMPL "&min";
		}
		else
		{
			print GENIMPL "0";
		}

		print GENIMPL ", ";

		if (defined $max)
		{
			print GENIMPL "&max";
		}
		else
		{
			print GENIMPL "0";
		}

		print GENIMPL "))\n";
	}
	elsif ($type eq "boolean")
	{
		print GENIMPL "\t\tif (!apply_boolean(key, data, &config->$name))\n";
	}
	elsif ($type =~ /(string|file|message)/)
	{
		print GENIMPL "\t\tif (!apply_string(key, data, &config->$name, (char*) \"\"))\n";
	}

	print GENIMPL "\t\t{\n" .
				  "\t\t\tLOG_ERROR(\"Configuration parse error on line %d\", line_count);\n" .
				  "\t\t\treturn -1;\n" .
				  "\t\t}\n" .
				  "\t\treturn 0;\n" .
				  "\t}\n\n";
}

sub write_c_impl_free(@)
{
	my @output = @_;
	my ($type, $name, $default, $advanced, $short, $desc, $since, $example) = @output;

	if ($type =~ /(string|file|message)/)
	{
		print GENIMPL "\thub_free(config->" . $name . ");\n\n" 
	}
}

sub write_c_impl_dump(@)
{
	my @output = @_;
	my ($type, $name, $default, $advanced, $short, $desc, $since, $example) = @output;
	my $out;
	my $val = "config->$name";
	my $test = "config->$name != $default";

	if ($type eq "int")
	{
		$out = "%d";
	}
	elsif ($type eq "boolean")
	{
		$out = "%s";
		$val = "config->$name ? \"yes\" : \"no\"";
	}
	elsif ($type =~ /(string|file|message)/)
	{
		$out = "\\\"%s\\\"";
		$test = "strcmp(config->$name, \"$default\") != 0";
	}

	print GENIMPL "\tif (!ignore_defaults || $test)\n";
	print GENIMPL "\t\tfprintf(stdout, \"$name = $out\\n\", $val);\n\n";
}

sub get_data($)
{
	my $p = shift;
	my $check = $p->first_child_matches("check");
	my @data = ($p->att("type"), $p->att("name"), $p->att("default"), $p->att("advanced"), $p->children_text("short"), $p->children_text("description"), $p->children_text("since"), $p->children_text("example"), $check);
	return @data;
}

