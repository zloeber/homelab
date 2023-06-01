#!/usr/bin/python
import unittest
import tempfile
import shutil
import os
import random
import string
import filer

class FilerTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.source_path = os.path.join(self.temp_dir, 'source')
        os.mkdir(self.source_path)
        self.target_path = os.path.join(self.temp_dir, 'target')
        os.mkdir(self.target_path)
        self.test_files = self.create_test_files()

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    def create_test_files(self):
        extensions = {'audio': ['mp3', 'flac', 'wav'], 
                      'photo': ['jpg', 'jpeg', 'png', 'gif'], 
                      'video': ['mp4', 'mkv', 'avi'], 
                      'other': ['txt', 'md', 'py']}
        test_files = []
        for ext_type, exts in extensions.items():
            for _ in range(25):
                file_name = ''.join(random.choices(string.ascii_lowercase, k=10))
                file_ext = random.choice(exts)
                file_path = os.path.join(self.source_path, f'{file_name}.{file_ext}')
                with open(file_path, 'w') as f:
                    f.write(file_name)
                test_files.append((file_path, ext_type))
        return test_files

    def test_run(self):
        filer.run(target_path=self.target_path, source_path=self.source_path)
        for file_path, ext_type in self.test_files:
            dest_folder = None
            if ext_type == 'audio':
                dest_folder = 'Music'
            elif ext_type == 'photo':
                dest_folder = 'Photos'
            elif ext_type == 'video':
                dest_folder = 'Videos'
            else:
                dest_folder = 'Other'
            dest_path = os.path.join(self.target_path, dest_folder)
            self.assertTrue(os.path.exists(os.path.join(dest_path, os.path.basename(file_path))))