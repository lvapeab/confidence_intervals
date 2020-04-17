# -*- coding: utf-8 -*-
from setuptools import setup

setup(name='confidence_intervals',
      version='0.1',
      description='Confidence intervals for structured prediction.',
      author='Alvaro Peris',
      author_email='lvapeab@gmail.com',
      url='https://github.com/lvapeab/confidence-intervals',
      download_url='https://github.com/lvapeab/confidence-intervals/archive/master.zip',
      license='MIT',
      classifiers=[
          'Intended Audience :: Developers',
          'Intended Audience :: Education',
          'Intended Audience :: Science/Research',
          'Programming Language :: Python :: 2',
          'Programming Language :: Python :: 2.7',
          'Programming Language :: Python :: 3',
          'Programming Language :: Python :: 3.6',
          'Programming Language :: Python :: 3.7',
          'Topic :: Software Development :: Libraries',
          'Topic :: Software Development :: Libraries :: Python Modules',
          "License :: OSI Approved :: MIT License"
      ],
      install_requires=[
          'art @ https://github.com/lvapeab/art/archive/master.zip',
      ],
      )
