from setuptools import setup

APP = ["get_up.py"]
OPTIONS = {
    "argv_emulation": False,
    "packages": ["rumps"],
    "plist": {
        "CFBundleName": "GetUp",
        "CFBundleDisplayName": "GetUp",
        "CFBundleIdentifier": "com.getup.reminder",
        "CFBundleShortVersionString": "1.0.0",
        "CFBundleVersion": "1",
        "LSUIElement": True,
    },
}

setup(
    name="GetUp",
    app=APP,
    options={"py2app": OPTIONS},
    setup_requires=["py2app"],
)
