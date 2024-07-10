#!/usr/bin/env python3

#
# PURPOSE
# This tool translates automatically i18n languages
#
# PREREQUISITES
# pip install deep-translator
#
 USAGE
# python3 translation.py --input_file ../../scripts/locales/en.lua --output_file ../../scripts/locales/es.lua --input_language en --output_language es
#
from deep_translator import GoogleTranslator
import argparse
import re

DEBUGGING = False
parser = argparse.ArgumentParser(description='Process input and output files with language parameters.')
parser.add_argument('--input_file', type=str, help='Path to the input file.')
parser.add_argument('--output_file', type=str, help='Path to the output file.')
parser.add_argument('--input_language', type=str, help='Input language code (e.g., en for English).')
parser.add_argument('--output_language', type=str, help='Output language code (e.g., ko for Korean).')

# Parse arguments

args = parser.parse_args()

input_file = args.input_file
output_file = args.output_file

# pattern to retrieve i18n string content
pattern = r'\s*\[\s*\"[^\"]+\"\s*\]\s*=\s*\"((?:\\.|[^\"])*)\"\s*,'

# pattern to retrieve non escaped "
pattern_non_escaped = r'(?<!\\)"'

# translator initialization
translator = GoogleTranslator(source=args.input_language, target=args.output_language)
translator = GoogleTranslator(source="en", target="fr")

# function to translate a given string
def translate_string(string_to_translate):
    return  str(translator.translate(string_to_translate))

# function that given in input a list of regex matches and a line
# translated the source file value and substitutes the translated value in the original line, returning the output line
def translate_and_replace_line(regex_matches, line):
    translated_value = translator.translate(str(regex_matches[0]))
    return line.replace(matches[0], str(re.sub(pattern_non_escaped, r'\"', str(translated_value))))



input_file = "/home/data/develop/ntopng/scripts/locales/en.lua"
output_file = "/home/data/develop/ntopng/scripts/locales/test.lua"


with open(input_file, encoding='utf-8') as f1:
    input_lines = f1.readlines()

with open(output_file, encoding='utf-8') as f2:
    output_lines = f2.readlines()

output_index = 0

# Compare lines and insert mismatched lines
for lineno, (line1, line2) in enumerate(zip(input_lines, output_lines), 1):    
    matches_input = line1.split("=")[0].strip()
    matches_output = line2.split("=")[0].strip()
    print(matches_input)
    print(matches_output)
    print("******************")
    if matches_input != matches_output:
        print(f"Line {lineno} mismatch:")
        print(f"Input file: {line1.strip()}")
        print(f"Output file: {line2.strip()}")

        # Insert the mismatched input line into the output file between current and next line
        output_lines.insert(output_index + 1, line1)
    output_index += 1



with open(input_file, 'r', encoding='utf-8') as infile, open(output_file, 'w', encoding='utf-8') as outfile:
    for line in infile:
        matches = re.findall(pattern, line)
        if (len(matches) > 0):
            line = translate_and_replace_line(matches, line)
            outfile.write(f"{str(line)}")
        else:
            outfile.write(line)
    
input_file = "/home/data/develop/ntopng/scripts/locales/en.lua"
output_file = "/home/data/develop/ntopng/scripts/locales/test.lua"

with open(input_file, 'r', encoding='utf-8') as infile, open(output_file, 'r+', encoding='utf-8') as outfile:

    input_line = infile.readline()
    output_line = outfile.readline()

    while input_line:
        if output_line:
            matches_input = input_line.split("=")[0].strip()
            matches_output = output_line.split("=")[0].strip()
        else:
            matches_output = None

        if matches_input == matches_output:
            output_line = outfile.readline().strip()  # Read next line from output
        else:
            print(f"Mismatch found. Input: '{input_line}', Output: '{output_line}'")
            # Move the output file pointer back to insert the line
            #current_pos = outfile.tell()
            #remaining_output = outfile.read()  # Read the rest of the file
            #outfile.seek(current_pos)  # Go back to the current position
            #outfile.write(input_line + "\n")  # Write the mismatched line
            #outfile.write(remaining_output)  # Append the rest of the file
            #outfile.seek(current_pos)  # Rewind to the current position for next comparison
            #output_line = input_line  # Consider the inserted line for next comparison

        input_line = infile.readline()  # Read next line from input

    print("Synchronization complete.")



##################

with open(input_file, 'r', encoding='utf-8') as infile, open(output_file, 'r+', encoding='utf-8') as outfile:
    input_line = infile.readline().strip()
    output_line = outfile.readline().strip()
    output_lines = []  # To store updated lines
    output_position = outfile.tell()

    while input_line:
        if output_line:
            matches_input = input_line.split("=")[0].strip()
            matches_output = output_line.split("=")[0].strip()
        else:
            matches_output = None
        
        if matches_input == matches_output:
            # If lines match, add the output line to the list and read the next output line
            output_lines.append(output_line + "\n")
            output_line = outfile.readline()  # Read next line from output
            output_position = outfile.tell()
            input_line = infile.readline()  # Move to the next input line
        else:
            print(f"Mismatch found. Input: '{input_line}', Output: '{output_line}'")
            # Add the mismatched input line to the output list
            output_lines.append(input_line + "\n")
            # Skip to re-read the mismatched output line and keep input line the same
            output_line = None  # Reset to re-read the same input line on next loop

    # Write the updated output lines back to the file
    outfile.seek(0)  # Go to the beginning of the file
    outfile.truncate()  # Clear the file content
    outfile.writelines(output_lines)  # Write all the lines

