from random import randint
import time
import sys


def myfunc(param):
    # this function waits random 1-3 seconds before returning
    time.sleep(randint(1, 3))
    return f"finished {param}"


if __name__ == "__main__":
    param = sys.argv[1]
    myfunc(param=param)