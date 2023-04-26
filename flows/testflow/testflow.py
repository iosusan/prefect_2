from prefect import flow
import time
from random import randint


@flow(name="testflow")
def my_flow(param):
    print(f"running for {param}")
    time.sleep(randint(1, 3))
    return f"finished {param}"


@flow
def concurrent_flows():
    print(my_flow("FIRST"))
    print(my_flow("SECOND"))


if __name__ == "__main__":
    concurrent_flows()
