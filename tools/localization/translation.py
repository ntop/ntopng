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


translator = GoogleTranslator(source=args.input_language, target=args.output_language)

def translate_string(string_to_translate, max_retries=3):
    return  str(translator.translate(string_to_translate))

if (DEBUGGING):
    # get file length in number of lines
    with open(input_file, 'r', encoding='utf-8') as infile:
            input_lines = infile.readlines()
    with open(output_file, 'r', encoding='utf-8') as transfile:
        translated_lines = transfile.readlines()

    total_lines = len(input_lines)

if (DEBUGGING):
    print(f"Total lines to process: {total_lines}")

done = 0

# pattern to retrieve i18n string content
pattern = r'\s*\[\s*\"[^\"]+\"\s*\]\s*=\s*\"((?:\\.|[^\"])*)\"\s*,'

# pattern to retrieve non escaped "
pattern_non_escaped = r'(?<!\\)"'

with open(input_file, 'r', encoding='utf-8') as infile, open(output_file, 'w', encoding='utf-8') as outfile:
    for line in infile:
        matches = re.findall(pattern, line)
        if (len(matches) > 0):
            translated_value = translator.translate(str(matches[0]))
            line = line.replace(matches[0], str(re.sub(pattern_non_escaped, r'\"', str(translated_value))))

            outfile.write(f"{str(line)}")
        else:
            outfile.write(line)
        
        done += 1        
        if (DEBUGGING):
            print(f"Translated: [{done}/{total_lines}]")
