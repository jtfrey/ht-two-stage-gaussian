#
# Locate job index details.
#
import os
import sys
import fnmatch
import re
import json
import argparse


class MappingRecord(object):

    def __init__(self, idx, prefix, information=dict()):
        self.idx = idx
        self.prefix = prefix
        self.parameters = information.get('parameters', dict())
        self.files = information.get('files', list())


#
# Setup command line argument parsing:
#
cli_parser = argparse.ArgumentParser(description='Extract job index information from mapping file')
cli_parser.add_argument('--mapping-file', '-m', metavar='<mapping-file>',
        dest='mapping_file',
        default=os.getenv('CATALOG_FILE', 'job-map.index'),
        help='Consult the given <mapping-file> for information')
cli_parser.add_argument('--chemical', '-c', metavar='<chemical-name>',
        dest='chemicals',
        action='append',
        default=[],
        help='Simple name of a chemical')
cli_parser.add_argument('--chemical-regex', '-r', metavar='<chemical-regex>',
        dest='chemical_regexes',
        action='append',
        default=[],
        help='Regular expression to match to name of a chemical')
cli_parser.add_argument('--chemical-pattern', '-p', metavar='<chemical-pattern>',
        dest='chemical_patterns',
        action='append',
        default=[],
        help='Filename-like pattern match to name of a chemical')
cli_parser.add_argument('--solvent', '-s', metavar='<solvent-name>',
        dest='solvents',
        action='append',
        default=[],
        help='Simple name of a solvent')
cli_parser.add_argument('--solvent-regex', '-R', metavar='<solvent-regex>',
        dest='solvent_regexes',
        action='append',
        default=[],
        help='Regular expression to match to name of a solvent')
cli_parser.add_argument('--solvent-pattern', '-P', metavar='<solvent-pattern>',
        dest='solvent_patterns',
        action='append',
        default=[],
        help='Filename-like pattern match to name of a solvent')
cli_parser.add_argument('--field', '-f',
        dest='field',
        default='directory',
        choices=['index','directory','files', 'parameters'],
        help='Which field should be printed for matched mapping records')

# Parse the arguments:
cli_args = cli_parser.parse_args()

# Index regex:
index_regex = re.compile('^\[(\d+):([^]]*)\]\s*(.*)$')

# Pre-compile regexes:
if len(cli_args.chemical_regexes) > 0:
    regexes = []
    for regex in cli_args.chemical_regexes:
        regexes.append(re.compile(regex))
    cli_args.chemical_regexes = regexes
if len(cli_args.solvent_regexes) > 0:
    regexes = []
    for regex in cli_args.solvent_regexes:
        regexes.append(re.compile(regex, re.IGNORECASE))
    cli_args.solvent_regexes = regexes

has_chemical_comparators = len(cli_args.chemicals) + len(cli_args.chemical_regexes) + len(cli_args.chemical_patterns) > 0
has_solvent_comparators = len(cli_args.solvents) + len(cli_args.solvent_regexes) + len(cli_args.solvent_patterns) > 0

# Open the mapping file:
try:
    with open(cli_args.mapping_file) as fptr:
        for line in fptr.readlines():
            # Break the line apart:
            index_match = index_regex.match(line)
            if index_match is not None:
                index_record = MappingRecord(int(index_match.group(1)), index_match.group(2), json.loads(index_match.group(3)))
                is_match = False
                if has_chemical_comparators:
                    for chemical in cli_args.chemicals:
                        if chemical == index_record.parameters['CHEMICAL']:
                            is_match = True
                            break
                    if not is_match:
                        for regex in cli_args.chemical_regexes:
                            if regex.search(index_record.parameters['CHEMICAL']) is not None:
                                is_match = True
                                break
                    if not is_match:
                        for pattern in cli_args.chemical_patterns:
                            if fnmatch.fnmatchcase(index_record.parameters['CHEMICAL'], pattern):
                                is_match = True
                                break
                    if is_match and has_solvent_comparators:
                        is_match = False
                        for solvent in cli_args.solvents:
                            if solvent.lower() == index_record.parameters['SOLVENT'].lower():
                                is_match = True
                                break
                        if not is_match:
                            for regex in cli_args.solvent_regexes:
                                if regex.search(index_record.parameters['SOLVENT']) is not None:
                                    is_match = True
                                    break
                        if not is_match:
                            for pattern in cli_args.solvent_patterns:
                                if fnmatch.fnmatchcase(index_record.parameters['SOLVENT'].lower(), pattern.lower()):
                                    is_match = True
                                    break
                elif has_solvent_comparators:
                    for solvent in cli_args.solvents:
                        if solvent.lower() == index_record.parameters['SOLVENT'].lower():
                            is_match = True
                            break
                    if not is_match:
                        for regex in cli_args.solvent_regexes:
                            if regex.search(index_record.parameters['SOLVENT']) is not None:
                                is_match = True
                                break
                    if not is_match:
                        for pattern in cli_args.solvent_patterns:
                            if fnmatch.fnmatchcase(index_record.parameters['SOLVENT'].lower(), pattern.lower()):
                                is_match = True
                                break
                if is_match:
                    if cli_args.field == 'index':
                        print(index_record.idx)
                    elif cli_args.field == 'directory':
                        print(index_record.prefix)
                    elif cli_args.field == 'files':
                        print(index_record.files)
                    elif cli_args.field == 'parameters':
                        print(index_record.parameters)

except Exception as E:
    sys.stderr.write('ERROR:  unable to process mapping file {:s}\n'.format(cli_args.mapping_file))
    sys.stderr.write('        {:s}\n'.format(str(E)))
    sys.exit(1)
