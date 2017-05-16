from __future__ import print_function

import argparse
import io
import json
import os
import sched
import sys
import time

import requests
import urllib2 as urllib
from PIL import Image
from openalpr import Alpr


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


class PreProcessRulesAction(argparse.Action):
    def __init__(self, option_strings, dest, nargs=None, **kwargs):
        super(PreProcessRulesAction, self).__init__(option_strings, dest, **kwargs)

    def __call__(self, parser, namespace, values, option_string=None):

        item = {"crop": None, "prewarp": None}
        value_components = values.split('=')

        if len(value_components) is 2:
            item["crop"] = self.__parse_crop(value_components[0])
            item["prewarp"] = value_components[1]
        elif len(value_components) == 1:
            if value_components[0].count(',') is 4:
                item["crop"] = value_components[0]
            else:
                item["prewarp"] = value_components[0]

        items = getattr(namespace, self.dest, None)
        if items is None:
            setattr(namespace, self.dest, [item])
        else:
            items.append(item)
        print(items)

    def __parse_crop(self, csv_crop):
        values = csv_crop.split(',')
        return int(values[0]), int(values[1]), int(values[2]), int(values[3])


def download_image(url):
    source_image = urllib.urlopen(url)
    image_data = io.BytesIO(source_image.read())
    return Image.open(image_data)


def process_image(alpr, image, rules):
    def run_alpr(alpr, image):
        image_bytes = io.BytesIO()
        image.save(image_bytes, format='JPEG')
        return alpr.recognize_array(image_bytes.getvalue())

    results = []
    if len(rules) == 0:
        results.append(run_alpr(alpr, image))
    else:
        for rule in rules:
            image_copy = image
            if rule["crop"]:
                image_copy = image.crop((rule["crop"]))
            if rule["prewarp"]:
                alpr.set_prewarp(rule["prewarp"])

            alpr_results = run_alpr(alpr, image_copy)
            results.append({'preprocessing_rule': rule, 'alpr_results': alpr_results})

    return results


parser = argparse.ArgumentParser(prog='OpenALPR Docker image',
                                 description='Dockerised OpenALPR for polling URLs - with additional image preprocessing')

parser.add_argument('input', help='url to poll for an image')
parser.add_argument('output', help='url to post the json response')
parser.add_argument('--country', help='country to set for ALPR', default='eu')
parser.add_argument('--region', help='region to set for ALPR', default='gb')
parser.add_argument('--verbose', help='increase output verbosity', action='store_true')
parser.add_argument('--interval', help='interval between polling for a new image to process', type=int, default=10)
parser.add_argument('--preprocess',
                    nargs='*',
                    help='prewarp value to apply against each, and/or the x1,y1,x2,y2 values to crop',
                    default=[],
                    action=PreProcessRulesAction)

args = parser.parse_args()

config_path = os.getenv('OPEN_ALPR_CONFIG_PATH')
open_alpr = Alpr(args.country, config_path, "/usr/share/openalpr/runtime_data")
if not open_alpr.is_loaded():
    print("Error loading OpenALPR")
    sys.exit(1)

open_alpr.set_default_region(args.region)


def poll(alpr, input_url, output_url, interval, preprocessing_rules):
    if args.verbose:
        print("Polling {}".format(input_url))

    image = None
    try:
        image = download_image(input_url)
    except urllib.URLError:
        eprint("Failed to poll {}".format(input_url))
        pass

    if image is not None:
        alpr_results = process_image(alpr, image, preprocessing_rules)
        json_data = json.dumps({"source": input_url, "results": alpr_results})

        if args.verbose:
            print("POST data to {}: {}".format(output_url, json_data))

        try:
            requests.post(output_url, data=json_data)
        except requests.exceptions.ConnectionError:
            eprint("Failed to POST data to {}".format(output_url))
            pass

    s.enter(interval, 1, poll, (alpr, input_url, output_url, interval, preprocessing_rules))


if args.verbose and len(args.preprocess) > 0:
    print("Rules loaded: {}".format(args.preprocess))

s = sched.scheduler(time.time, time.sleep)
poll(open_alpr, args.input, args.output, args.interval, args.preprocess)
s.run()
