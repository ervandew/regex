# Author:  Eric Van Dewoestine
#
# License:
#   Copyright (c) 2005 - 2011, Eric Van Dewoestine
#   All rights reserved.
#
#   Redistribution and use of this software in source and binary forms, with
#   or without modification, are permitted provided that the following
#   conditions are met:
#
#   * Redistributions of source code must retain the above
#     copyright notice, this list of conditions and the
#     following disclaimer.
#
#   * Redistributions in binary form must reproduce the above
#     copyright notice, this list of conditions and the
#     following disclaimer in the documentation and/or other
#     materials provided with the distribution.
#
#   * Neither the name of Eric Van Dewoestine nor the names of its
#     contributors may be used to endorse or promote products derived from
#     this software without specific prior written permission of
#     Eric Van Dewoestine.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
#   IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
#   THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
#   PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
#   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
#   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
#   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
#   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
#   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import re, sys

try:
  from StringIO import StringIO # python 2
except ImportError:
  from io import StringIO # python 3

def main():
  f = open(sys.argv[1], 'r')
  flags = len(sys.argv) > 2 and sys.argv[2] or ''

  try:
    content = f.read()
    regex_text = content.split('\n', 1)
    if len(regex_text) != 2:
      return

    regex, text = regex_text

    pflags = 0
    if 'm' in flags:
      pflags |= re.MULTILINE
    if 'i' in flags:
      pflags |= re.IGNORECASE
    if 'd' in flags:
      pflags |= re.DOTALL
    pattern = re.compile(regex, pflags)

    pos = len(content) - len(text)
    for match in pattern.finditer(text):
      string = StringIO()
      string.write('%s-%s' % (match.start() + pos, match.end() + pos - 1))
      if(match.groups()):
        for ii in range(1, len(match.groups()) + 1):
          if match.start(ii) >= 0:
            string.write(',%s-%s' % (match.start(ii) + pos, match.end(ii) + pos - 1))

      print(string.getvalue())

  finally:
    f.close()

if __name__ == '__main__':
  main()
