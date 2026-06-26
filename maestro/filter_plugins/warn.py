"""Filter that emits a real Ansible warning (the magenta [WARNING]: line)
and returns the value unchanged, so it can be used inline in a template."""

from ansible.utils.display import Display

display = Display()


def warn(value):
    display.warning(value if isinstance(value, str) else str(value))
    return value


class FilterModule(object):
    def filters(self):
        return {"warn": warn}
