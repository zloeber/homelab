#!/usr/bin/python
import click
import yaml
import os
import hashlib
from multiprocessing import Pool

def get_hash(file_path):
    hasher = hashlib.md5()
    with open(file_path, 'rb') as f:
        buf = f.read()
        hasher.update(buf)
    return hasher.hexdigest()

def move_file(file, target_path, show_progress, report):
    extension = os.path.splitext(file)[1][1:].lower()
    if extension in ['mp3', 'flac', 'wav']:
        dest_folder = 'Music'
    elif extension in ['jpg', 'jpeg', 'png', 'gif']:
        dest_folder = 'Photos'
    elif extension in ['mp4', 'mkv', 'avi']:
        dest_folder = 'Videos'
    else:
        dest_folder = 'Other'
    dest_path = os.path.join(target_path, dest_folder)
    os.makedirs(dest_path, exist_ok=True)
    source_path = os.path.join(source_path, file)
    dest_file = os.path.join(dest_path, file)
    if os.path.exists(dest_file):
        if get_hash(source_path) != get_hash(dest_file):
            os.replace(source_path, dest_file)
    else:
        os.replace(source_path, dest_file)
    if show_progress:
        click.echo(f'{file} is moved to {dest_path}')
    if report:
        report[dest_folder] += 1

@click.group()
@click.option('--config', '-c', type=click.Path(exists=True), help='Path to YAML configuration file.')
def filer(config):
    target_path = None
    source_path = os.path.abspath(os.path.curdir)
    if config:
        with open        (config, 'r') as config_file:
            config = yaml.safe_load(config_file)
            global_config = config.get('global', {})
            target_path = global_config.get('target_path')
            source_path = global_config.get('source_path', source_path)
    return target_path, source_path

@filer.command()
@click.option('--target_path', '-p', help='Target path to run the command.', default=lambda: filer()[0])
@click.option('--source_path', '-s', help='Source path to run the command.', default=lambda: filer()[1])
@click.option('--show-progress', '-sp', is_flag=True, help='Show the overall progress of file move operations.')
@click.option('--report', '-r', is_flag=True, help='Output a report of how many files were moved to each target folder.')
def run(target_path, source_path, show_progress, report):
    if target_path is None:
        target_path = os.path.abspath(os.path.curdir)
    os.makedirs(target_path, exist_ok=True)
    if not report:
        report = {'Music': 0, 'Photos': 0, 'Videos': 0, 'Other': 0}
    with Pool() as p:
        files = os.listdir(source_path)
        p.map(move_file, files, [target_path] * len(files), [show_progress] * len(files), [report] * len(files))
    if report:
        click.echo(f'Moved {report["Music"]} files to Music')
        click.echo(f'Moved {report["Photos"]} files to Photos')
        click.echo(f'Moved {report["Videos"]} files to Videos')
        click.echo(f'Moved {report["Other"]} files to Other')
