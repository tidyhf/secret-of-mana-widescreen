"""Build the Secret of Mana widescreen patch.

usage: python build.py <clean "Secret of Mana (USA).sfc"> [--asar asar.exe] [--flips flips.exe]

Produces "Secret of Mana (USA) [WS].sfc" and "Secret of Mana (USA).bps" next to this script.
Requires asar 1.9x (https://github.com/RPGHacker/asar) and Flips (https://github.com/Alcaro/Flips).
"""
import argparse, hashlib, os, shutil, subprocess, sys

H = os.path.dirname(os.path.abspath(__file__))
CLEAN_SHA1 = '8133041a363e3cc68cedef40b49b6d20d03c505d'

ap = argparse.ArgumentParser()
ap.add_argument('rom')
ap.add_argument('--asar', default='asar')
ap.add_argument('--flips', default='flips')
a = ap.parse_args()

data = open(a.rom, 'rb').read()
if len(data) % 0x8000 == 512:
    sys.exit('ROM has a copier header; remove it first')
if hashlib.sha1(data).hexdigest() != CLEAN_SHA1:
    print('warning: ROM SHA-1 does not match the clean USA release')

out = os.path.join(H, 'Secret of Mana (USA) [WS].sfc')
shutil.copyfile(a.rom, out)
r = subprocess.run([a.asar, '--no-title-check', '--fix-checksum=on', os.path.join(H, 'somws.asm'), out])
if r.returncode:
    sys.exit('asar failed')
r = subprocess.run([a.flips, '--create', '--bps', a.rom, out, os.path.join(H, 'Secret of Mana (USA).bps')])
if r.returncode:
    sys.exit('flips failed')
print('built', out)
