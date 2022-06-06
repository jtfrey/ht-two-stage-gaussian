#
# Locate all viable CHEMICAL species in the COMPLETE_DIR
#
import os
import sys
import fnmatch
import re
import json
import argparse

#
# The following class cluster implements the various name-matching
# operations available to the exclude/include filtering:
#
class IncludeNameMatch(object):

    DISPOSITION_INCLUDE = 1
    DISPOSITION_EXCLUDE = 2

    def __init__(self, string):
        self.string = str(string)
    
    def disposition(self):
        return self.DISPOSITION_INCLUDE if 'Include' in self.__class__.__name__ else self.DISPOSITION_EXCLUDE
    
    def is_match(self, other_string):
        return other_string == self.string

class ExcludeNameMatch(IncludeNameMatch):

    pass

class IncludeNameMatchCaseless(IncludeNameMatch):

    def is_match(self, other_string):
        return other_string.lower() == self.string.lower()

class ExcludeNameMatchCaseless(IncludeNameMatchCaseless):

    pass



class IncludeNameFnMatch(IncludeNameMatch):

    def is_match(self, other_string):
        return fnmatch.fnmatchcase(other_string, self.string)

class ExcludeNameFnMatch(IncludeNameFnMatch):

    pass
        
class IncludeNameFnMatchCaseless(IncludeNameFnMatch):

    def is_match(self, other_string):
        return fnmatch.fnmatch(other_string, self.string)

class ExcludeNameFnMatchCaseless(IncludeNameFnMatchCaseless):

    pass



class IncludeNameRegexMatch(IncludeNameMatch):

    def __init__(self, string):
        super(IncludeNameRegexMatch, self).__init__(string)
        self.regex = re.compile(string)
    
    def is_match(self, other_string):
        return self.regex.search(other_string) is not None

class ExcludeNameRegexMatch(IncludeNameRegexMatch):

    pass

class IncludeNameRegexMatchCaseless(IncludeNameMatch):

    def __init__(self, string):
        super(IncludeNameRegexMatch, self).__init__(string)
        self.regex = re.compile(string, re.IGNORECASE)
    
    def is_match(self, other_string):
        return self.regex.search(other_string) is not None

class ExcludeNameRegexMatchCaseless(IncludeNameRegexMatchCaseless):

    pass



#
# Setup command line argument parsing:
#
cli_parser = argparse.ArgumentParser(description='Generate lists of available CHEMICAL species')
cli_parser.add_argument('--format', '-f',
        dest='format',
        default='csv',
        choices=['csv', 'lines', 'json'],
        help='Emit the list of species as a single comma-separated line (csv), one name per line (lines), or a JSON document (json)')
        
cli_dynamic_names_parser = cli_parser.add_argument_group('Dynamic list of CHEMICAL names', 'Use of these options controls the dynamic build of CHEMICAL name list from a completed calculations directory.  Exclude/include rules are applied in the order they are specified.')
cli_dynamic_names_parser.add_argument('--base-list', '-b',
        dest='base_list',
        default='all',
        choices=['all', 'none'],
        help='The list of selected CHEMICAL names can start with "all" names present or with "none" of the names present; the action of exclude/include options then dictates how that list is modified (default is "all")')
cli_dynamic_names_parser.add_argument('--short-circuit', '-s',
        dest='should_short_circuit',
        default=False,
        action='store_true',
        help='The first-matched exclude/include rule decides a name''s fate.  By default, the last-matched rule is used.')
cli_dynamic_names_parser.add_argument('--completed-dir', '-D', metavar='<directory>',
        dest='completed_dir',
        default=os.getenv('COMPLETED_DIR', None),
        help='Search this directory for CHEMICAL species (default: {:s})'.format(os.getenv('COMPLETED_DIR', 'n/a')))
cli_dynamic_names_parser.add_argument('--exclude', '-e', metavar='<name>',
        dest='filters',
        action='append',
        type=ExcludeNameMatch,
        help='Omit species with the given <name> from the list (can be used multiple times)')
cli_dynamic_names_parser.add_argument('--exclude-regex', '-r', metavar='<regular-expression>',
        dest='filters',
        action='append',
        type=ExcludeNameRegexMatch,
        help='Omit species whose name matches the given <regular-expression> from the list (can be used multiple times)')
cli_dynamic_names_parser.add_argument('--exclude-pattern', '-p', metavar='<glob-pattern>',
        dest='filters',
        action='append',
        type=ExcludeNameFnMatch,
        help='Omit species whose name matches the given <glob-pattern> from the list (can be used multiple times)')
cli_dynamic_names_parser.add_argument('--include', '-i', metavar='<name>',
        dest='filters',
        action='append',
        type=IncludeNameMatch,
        help='Include species with the given <name> from the list (can be used multiple times)')
cli_dynamic_names_parser.add_argument('--include-regex', '-R', metavar='<regular-expression>',
        dest='filters',
        action='append',
        type=IncludeNameRegexMatch,
        help='Include species whose name matches the given <regular-expression> from the list (can be used multiple times)')
cli_dynamic_names_parser.add_argument('--include-pattern', '-P', metavar='<glob-pattern>',
        dest='filters',
        action='append',
        type=IncludeNameFnMatch,
        help='Include species whose name matches the given <glob-pattern> from the list (can be used multiple times)')

cli_simple_names_parser = cli_parser.add_argument_group('Static list of CHEMICAL names', 'Use of at least one of these options disables the dynamic listing behavior.')
cli_simple_names_parser.add_argument('--name-list', '-l', metavar='<file>',
        dest='txt_name_list',
        help='Read a list of CHEMICAL names from the provided <file> (single name per line)')
cli_simple_names_parser.add_argument('--json-name-list', '-j', metavar='<json-file>',
        dest='json_name_list',
        help='Read a list of CHEMICAL names from the provided <json-file>; the document in the file should be a list of strings')

# Parse the arguments:
cli_args = cli_parser.parse_args()

#
# Start with an empty list...
#
CHEMICALS = []

#
# Do we have any of the static list options defined?
#
if cli_args.txt_name_list or cli_args.json_name_list:
    if cli_args.txt_name_list:
        try:
            if cli_args.txt_name_list == '-':
                for CHEMICAL in sys.stdin.readlines():
                    CHEMICAL = CHEMICAL.strip()
                    if CHEMICAL not in CHEMICALS:
                        CHEMICALS.append(CHEMICAL)
            else:
                with open(cli_args.txt_name_list) as fptr:
                    for CHEMICAL in fptr.readlines():
                        CHEMICAL = CHEMICAL.strip()
                        if CHEMICAL not in CHEMICALS:
                            CHEMICALS.append(CHEMICAL)
        except Exception as E:
            sys.stderr.write('ERROR:  unable to read CHEMICAL names from text file `{:s}`\n'.format(cli_args.txt_name_list))
            sys.stderr.write('        {:s}\n'.format(str(E)))
            sys.exit(22)
    if cli_args.json_name_list:
        try:
            if cli_args.json_name_list == '-':
                for CHEMICAL in json.load(sys.stdin):
                    if CHEMICAL not in CHEMICALS:
                        CHEMICALS.append(CHEMICAL)
            else:
                with open(cli_args.json_name_list) as fptr:
                    for CHEMICAL in json.load(fptr):
                        if CHEMICAL not in CHEMICALS:
                            CHEMICALS.append(CHEMICAL)
        except Exception as E:
            sys.stderr.write('ERROR:  unable to read CHEMICAL names from JSON file `{:s}`\n'.format(cli_args.json_name_list))
            sys.stderr.write('        {:s}\n'.format(str(E)))
            sys.exit(22)
else:
    # Does the completed directory exist?
    if not os.path.isdir(cli_args.completed_dir):
        sys.stderr.write('ERROR:  the completed results directory `{:s}` does not exist\n'.format(cli_args.completed_dir))
        sys.exit(1)
    
    # Look for directories under the completed directory:
    for root_dir, sub_dirs, files in os.walk(cli_args.completed_dir):
        for CHEMICAL in sub_dirs:
            if os.path.isfile(os.path.join(root_dir, CHEMICAL, '{:s}.chk'.format(CHEMICAL))):
                # Initial disposition:
                should_add = True if cli_args.base_list == 'all' else False
                if cli_args.filters:        
                    # Apply any exclude/include tests:
                    for rule in cli_args.filters:
                        if rule.is_match(CHEMICAL):
                            should_add = (rule.disposition() == IncludeNameMatch.DISPOSITION_INCLUDE)
                            if cli_args.should_short_circuit:
                                break
                # Add to the list?
                if should_add:
                    CHEMICALS.append(CHEMICAL)
                    
        # Empty-out the sub-directory list so that the walk does not recurse into lower directories:
        del sub_dirs[:]

# If we generated any names, print the list separated by commas:
if len(CHEMICALS):
    if cli_args.format == 'csv':
        print(','.join(CHEMICALS))
    elif cli_args.format == 'lines':
        print('\n'.join(CHEMICALS))
    elif cli_args.format == 'json':
        print(json.dumps(CHEMICALS))

