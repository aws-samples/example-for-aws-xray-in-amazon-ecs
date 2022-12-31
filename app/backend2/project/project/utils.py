import os
from configparser import ConfigParser
from django.utils.crypto import get_random_string


def load_secret_key_from_config(config_filepath):
    config = None

    if not os.path.exists(config_filepath):
        config = ConfigParser()
        config.add_section('django')
        config['django']['secret_key'] = get_random_string(64)
        with open(config_filepath, 'w') as config_file:
            config.write(config_file)

    if not config:
        config = ConfigParser()
        config.read_file(open(config_filepath))

    if not config.has_section('django') or not config.get('django', 'secret_key', fallback=None):
        raise KeyError('`django.secret_key` is missing in the config file.')

    return config['django']['secret_key']
