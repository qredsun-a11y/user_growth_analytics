from setuptools import setup, find_packages

setup(
    name="user_growth_analytics",
    version="0.0.1",
    description="User Growth Analytics - 用户增长与流失分析演示 App",
    author="Your Company",
    author_email="dev@example.com",
    packages=find_packages(),
    include_package_data=True,
    install_requires=[
        "frappe"
    ],
    classifiers=[
        "Programming Language :: Python :: 3.10",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    python_requires=">=3.10",
)
