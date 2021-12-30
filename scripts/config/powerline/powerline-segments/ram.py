from __future__ import (unicode_literals, division, absolute_import, print_function)
import psutil

def _ram():
	memory = psutil.virtual_memory();
	total = memory.total / 1073741824;
	used = (memory.total - memory.available) / 1073741824;
	return total, used;

def _swap():
	memory = psutil.swap_memory();
	total = memory.total / 1073741824;
	used = memory.total * (memory.percent/100) / 1073741824;
	return total, used;

def format_memory(format, total, used):
	gradient_level = (used / total) * 100;

	return [{
		'contents': format.format(used),
		'highlight_groups': ['system_load_gradient', 'system_load'],
		'divider_highlight_group': 'background:divider',
		'gradient_level': gradient_level,
	}];

def used_ram(pl, format='{:.1f}GB'):
	'''Return the current used ram in GiB'''
	
	try:
		total, used = _ram();
	except:
		total = 1;
		used = 0;

	return format_memory(format, total, used);

def used_swap(pl, format='{:.1f}GB'):
	'''Return the current used swap in GiB'''

	try:
		total, used = _swap();
	except:
		total = 1;
		used = 0;

	return format_memory(format, total, used);

def used_total(pl, format='{:.1f}GB'):
	'''Return the current used memory in GiB (ram + swap)'''

	try:
		ramtotal, ramused = _ram();
		swaptotal, swapused = _swap();
		total, used = ramtotal+swaptotal, ramused+swapused;
	except:
		total = 1;
		used = 0;

	return format_memory(format, total, used);