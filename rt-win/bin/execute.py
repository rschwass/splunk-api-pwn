#!/usr/bin/env python3
import splunk.admin as admin
import subprocess
import xml.etree.ElementTree as ET

class ExecRestHandler(admin.MConfigHandler):
    def __init__(self, scriptMode, ctxInfo):
        admin.MConfigHandler.__init__(self, scriptMode, ctxInfo)
        self.shouldAutoList = False

    def setup(self):
        """
        Defines valid arguments that this endpoint accepts.
        """
        self.supportedArgs.addOptArg("command")  # Accepts "command" as an optional argument

    def handleEdit(self, confInfo):
        """
        Handles a POST request to /services/admin/exec/<target>
        """
        command = self.callerArgs.get("command", [""])[0]  # Extract the "command" parameter
        target = self.callerArgs.id if self.callerArgs.id else "exec"

        if not command:
            confInfo[target].append("status", "error")
            confInfo[target].append("message", "No command provided.")
            return

        try:
            # 🚀 Run the command securely (prevents shell injection)
            result = subprocess.run(command.split(), capture_output=True, text=True, timeout=5)

            # 🚀 Generate XML output
            confInfo[target].append("status", "success" if result.returncode == 0 else "error")
            confInfo[target].append("output", result.stdout.strip() or "No output")
            confInfo[target].append("error", result.stderr.strip() or "No errors")
        except Exception as e:
            confInfo[target].append("status", "error")
            confInfo[target].append("message", str(e))

# Initialize the REST handler
admin.init(ExecRestHandler, admin.CONTEXT_APP_AND_USER)