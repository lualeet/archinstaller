from __future__ import (unicode_literals, division, absolute_import, print_function)
import subprocess

def temperature(pl, format='{temp}°C'):
	'''Return the current GPU Temperature'''
	
	try:
		process = "nvidia-smi -q | grep -Po \"(?<=GPU Current Temp.{20})\d+\"";
		temperature = subprocess.check_output(process, shell=True);
	except:
		temperature = "0"

	temperature = int(temperature);

	gradient_level = max(min(temperature+30 / 70, 1), 0);

	return [{
		'contents': format.format(temp=temperature),
		'highlight_groups': ['system_load_gradient', 'system_load'],
		'divider_highlight_group': 'background:divider',
		'gradient_level': gradient_level,
	}]