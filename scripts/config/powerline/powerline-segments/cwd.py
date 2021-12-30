from __future__ import (unicode_literals, division, absolute_import, print_function)
import os, re


def where(pl, format='%Y-%m-%d', istime=False, timezone=None):
	'''Return the current zsh last-working-dir.
	'''

	home = os.path.expanduser('~')

	try:
		f = open(home+'/.oh-my-zsh/cache/last-working-dir')
		contents = f.read()[:-1]
		contents = contents.replace(home, '~')
	except:
		contents = "~"

	#if len(contents) > 1:
		#contents += "/"

	try:
		subpath = re.split('.+((?<=\/).+)', contents)[1]
		active  = re.split(subpath, contents)[0]
	except:
		subpath = contents
		active  = ""

	return [
		{
			'contents': active,
			'highlight_groups': ['cwd-pretty'],
			'divider_highlight_group': 'background:divider',
		},
		{
			'contents': subpath,
			'highlight_groups': ['cwd-pretty-current'],
			'divider_highlight_group': 'background:divider',
		}
	]

