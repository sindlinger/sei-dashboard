import io
import unittest
from contextlib import redirect_stdout

from seiautomation import cli


class CliExampleTests(unittest.TestCase):
    def test_print_examples_lists_all_commands(self) -> None:
        buffer = io.StringIO()
        with redirect_stdout(buffer):
            cli._print_examples()
        output = buffer.getvalue()
        self.assertIn("Comandos frequentes", output)
        for _, command in cli.HELP_EXAMPLES:
            self.assertIn(command, output)


if __name__ == "__main__":
    unittest.main()
