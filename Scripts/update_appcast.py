#!/usr/bin/env python3

import argparse
import sys
import xml.etree.ElementTree as ET

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"


def indent(elem: ET.Element, level: int = 0) -> None:
    i = "\n" + level * "  "
    if len(elem):
        if not elem.text or not elem.text.strip():
            elem.text = i + "  "
        for child in elem:
            indent(child, level + 1)
        if not elem.tail or not elem.tail.strip():
            elem.tail = i
    else:
        if level and (not elem.tail or not elem.tail.strip()):
            elem.tail = i


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Insert a Sparkle <item> into appcast.xml.")
    parser.add_argument("--appcast", required=True, help="Path to appcast.xml")
    parser.add_argument("--version", required=True, help="Short version string (e.g. 0.1.0)")
    parser.add_argument("--build-version", default=None, help="Build version (defaults to --version)")
    parser.add_argument("--pubdate", required=True, help="RFC822 date string")
    parser.add_argument("--min-system-version", required=True, help="Minimum macOS version (e.g. 11.0)")
    parser.add_argument("--url", required=True, help="Enclosure URL")
    parser.add_argument("--length", required=True, type=int, help="Enclosure length in bytes")
    parser.add_argument("--signature", required=True, help="sparkle:edSignature value (base64)")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    build_version = args.build_version or args.version

    ET.register_namespace("sparkle", SPARKLE_NS)

    try:
        tree = ET.parse(args.appcast)
    except Exception as exc:
        print(f"Failed to parse appcast: {exc}", file=sys.stderr)
        return 1

    rss = tree.getroot()
    channel = rss.find("channel")
    if channel is None:
        print("appcast.xml missing <channel>", file=sys.stderr)
        return 1

    item = ET.Element("item")
    ET.SubElement(item, "title").text = args.version
    ET.SubElement(item, "pubDate").text = args.pubdate
    ET.SubElement(item, f"{{{SPARKLE_NS}}}version").text = build_version
    ET.SubElement(item, f"{{{SPARKLE_NS}}}shortVersionString").text = args.version
    ET.SubElement(item, f"{{{SPARKLE_NS}}}minimumSystemVersion").text = args.min_system_version

    enclosure_attrs = {
        "url": args.url,
        "length": str(args.length),
        "type": "application/octet-stream",
        f"{{{SPARKLE_NS}}}edSignature": args.signature,
    }
    ET.SubElement(item, "enclosure", enclosure_attrs)

    channel_children = list(channel)
    insert_index = len(channel_children)
    for idx, child in enumerate(channel_children):
        if child.tag == "item":
            insert_index = idx
            break

    channel.insert(insert_index, item)

    indent(rss)
    tree.write(args.appcast, encoding="utf-8", xml_declaration=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

