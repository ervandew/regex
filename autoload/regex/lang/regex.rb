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
require 'stringio'

def main()
  flags = ''
  if ARGV.length > 1 and ARGV[1]
    flags = ARGV[1]
  end

  File.open(ARGV[0], 'r') do |f|
    content = f.read()
    regex_text = content.split("\n", 2)

    if regex_text.length != 2
      return
    end

    regex = regex_text[0]
    text = regex_text[1]

    pflags = nil
    # ruby's multiline == everyone else's dotall
    if flags.index('d')
      pflags = Regexp::MULTILINE
    end
    if flags.index('i')
      if pflags == nil
        pflags = Regexp::IGNORECASE
      else
        pflags |= Regexp::IGNORECASE
      end
    end
    pattern = Regexp.new(regex, pflags)

    pos = content.length - text.length
    while m = pattern.match(text)
      string = StringIO.new
      string << "#{m.begin(0) + pos}-#{m.end(0) + pos - 1}"
      for ii in Range.new(1, m.length - 1)
        if m.begin(ii) && m.begin(ii) >= 0
          string << ",#{m.begin(ii)+ pos }-#{m.end(ii) + pos - 1}"
        end
      end

      pos += m.end(0)

      # this gets us ruby 1.8 compatability but can result in false
      # positive '^' patterns
      text = text[m.end(0)..-1]

      puts string.string
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  main()
end
