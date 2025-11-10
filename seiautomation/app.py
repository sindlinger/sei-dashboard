from __future__ import annotations

from typing import Callable, Dict

from PySide6 import QtCore, QtGui, QtWidgets

from .config import Settings
from .tasks import download_zip_lote, listar_processos, preencher_anotacoes_ok
from .tasks.list_processes import ResumoProcessos


class Worker(QtCore.QThread):
    log_signal = QtCore.Signal(str)
    finished_signal = QtCore.Signal(bool, str)

    def __init__(
        self, tasks: Dict[str, Callable[[Callable[[str], None]], None]], parent: QtCore.QObject | None = None
    ) -> None:
        super().__init__(parent)
        self._tasks = tasks

    def run(self) -> None:  # noqa: D401
        try:
            for name, task in self._tasks.items():
                self.log_signal.emit(f"Iniciando: {name}")
                task(lambda msg, prefix=name: self.log_signal.emit(f"{prefix}: {msg}"))
                self.log_signal.emit(f"Concluído: {name}")
            self.finished_signal.emit(True, "Todas as tarefas foram concluídas.")
        except Exception as exc:  # noqa: BLE001
            self.finished_signal.emit(False, f"Erro: {exc}")


class MainWindow(QtWidgets.QWidget):
    summary_signal = QtCore.Signal(object)

    def __init__(self, settings: Settings) -> None:
        super().__init__()
        self.settings = settings
        self.setWindowTitle("SEIAutomation")
        self.resize(520, 520)
        self._current_operation: str | None = None
        self._last_summary: object | None = None

        self.checkbox_download = QtWidgets.QCheckBox("Baixar processos do bloco (ZIP)")
        self.checkbox_anotacoes = QtWidgets.QCheckBox('Preencher anotações com "OK"')
        self.checkbox_listar = QtWidgets.QCheckBox("Listar processos e status")
        self.checkbox_headless = QtWidgets.QCheckBox("Executar em modo headless (sem janela)")
        self.checkbox_headless.setChecked(True)
        self.checkbox_auto_credentials = QtWidgets.QCheckBox("Preencher credenciais automaticamente")
        self.checkbox_auto_credentials.setChecked(self.settings.is_admin)

        self.input_username = QtWidgets.QLineEdit(self.settings.username)
        self.input_password = QtWidgets.QLineEdit(self.settings.password)
        self.input_password.setEchoMode(QtWidgets.QLineEdit.Password)

        creds_group = QtWidgets.QGroupBox("Credenciais do SEI")
        creds_form = QtWidgets.QFormLayout(creds_group)
        creds_form.addRow("Usuário (CPF)", self.input_username)
        creds_form.addRow("Senha", self.input_password)

        self.summary_group = QtWidgets.QGroupBox("Painel do bloco")
        summary_layout = QtWidgets.QGridLayout(self.summary_group)
        self.summary_labels = {
            "total": QtWidgets.QLabel("0"),
            "ok": QtWidgets.QLabel("0"),
            "pendentes": QtWidgets.QLabel("0"),
            "baixados": QtWidgets.QLabel("0"),
            "faltando": QtWidgets.QLabel("0"),
        }
        summary_layout.addWidget(QtWidgets.QLabel("Total de processos"), 0, 0)
        summary_layout.addWidget(self.summary_labels["total"], 0, 1)
        summary_layout.addWidget(QtWidgets.QLabel("Com anotação OK"), 1, 0)
        summary_layout.addWidget(self.summary_labels["ok"], 1, 1)
        summary_layout.addWidget(QtWidgets.QLabel("Pendentes"), 2, 0)
        summary_layout.addWidget(self.summary_labels["pendentes"], 2, 1)
        summary_layout.addWidget(QtWidgets.QLabel("ZIPs salvos"), 3, 0)
        summary_layout.addWidget(self.summary_labels["baixados"], 3, 1)
        summary_layout.addWidget(QtWidgets.QLabel("Sem ZIP"), 4, 0)
        summary_layout.addWidget(self.summary_labels["faltando"], 4, 1)

        filtros_group = QtWidgets.QGroupBox("Filtros da listagem")
        filtros_layout = QtWidgets.QFormLayout(filtros_group)
        self.annotation_filter = QtWidgets.QComboBox()
        self.annotation_filter.addItem("Todas", userData=None)
        self.annotation_filter.addItem("Somente pendentes", userData="pending")
        self.annotation_filter.addItem("Somente com OK", userData="ok")
        self.zip_filter = QtWidgets.QComboBox()
        self.zip_filter.addItem("Todos", userData=None)
        self.zip_filter.addItem("Somente com ZIP salvo", userData="with_zip")
        self.zip_filter.addItem("Somente sem ZIP", userData="without_zip")
        filtros_layout.addRow("Anotações", self.annotation_filter)
        filtros_layout.addRow("Status do ZIP", self.zip_filter)

        self.log = QtWidgets.QPlainTextEdit()
        self.log.setReadOnly(True)

        self.run_button = QtWidgets.QPushButton("Executar tarefas selecionadas")
        self.run_button.clicked.connect(self._start_tasks)
        self.refresh_button = QtWidgets.QPushButton("Atualizar painel")
        self.refresh_button.clicked.connect(self._start_dashboard_refresh)
        self.close_button = QtWidgets.QPushButton("Fechar")
        self.close_button.clicked.connect(self.close)

        button_layout = QtWidgets.QHBoxLayout()
        button_layout.addWidget(self.refresh_button)
        button_layout.addWidget(self.run_button)
        button_layout.addWidget(self.close_button)

        layout = QtWidgets.QVBoxLayout(self)
        layout.addWidget(creds_group)
        layout.addWidget(self.summary_group)
        layout.addWidget(self.checkbox_download)
        layout.addWidget(self.checkbox_anotacoes)
        layout.addWidget(self.checkbox_listar)
        layout.addWidget(filtros_group)
        layout.addWidget(self.checkbox_headless)
        layout.addWidget(self.checkbox_auto_credentials)
        layout.addWidget(self.log)
        layout.addLayout(button_layout)

        self.worker: Worker | None = None
        self._setup_tray_icon()
        self.summary_signal.connect(self._apply_summary)

    def _setup_tray_icon(self) -> None:
        icon = self.style().standardIcon(QtWidgets.QStyle.SP_ComputerIcon)
        self.tray = QtWidgets.QSystemTrayIcon(icon, self)
        self.tray.setToolTip("SEIAutomation")

        menu = QtWidgets.QMenu()
        action_show = menu.addAction("Abrir janela")
        action_show.triggered.connect(self.showNormal)
        action_quit = menu.addAction("Sair")
        action_quit.triggered.connect(QtWidgets.QApplication.instance().quit)
        self.tray.setContextMenu(menu)
        self.tray.activated.connect(self._on_tray_activated)
        self.tray.show()

    def _on_tray_activated(self, reason: QtWidgets.QSystemTrayIcon.ActivationReason) -> None:
        if reason == QtWidgets.QSystemTrayIcon.DoubleClick:
            self.showNormal()
            self.activateWindow()

    def _append_log(self, message: str) -> None:
        self.log.appendPlainText(message)
        self.log.verticalScrollBar().setValue(self.log.verticalScrollBar().maximum())

    def _start_tasks(self) -> None:
        runtime_settings = self._runtime_settings()
        if runtime_settings is None:
            return

        tasks_to_run: Dict[str, Callable[[Callable[[str], None]], None]] = {}
        headless = self.checkbox_headless.isChecked()
        auto_credentials = self.checkbox_auto_credentials.isChecked()

        if self.checkbox_download.isChecked():
            tasks_to_run["Download de ZIPs"] = lambda progress, settings=runtime_settings: download_zip_lote(
                settings, headless=headless, progress=progress, auto_credentials=auto_credentials
            )
        if self.checkbox_anotacoes.isChecked():
            tasks_to_run["Atualização de anotações"] = lambda progress, settings=runtime_settings: preencher_anotacoes_ok(
                settings, headless=headless, progress=progress, auto_credentials=auto_credentials
            )
        if self.checkbox_listar.isChecked():
            tasks_to_run["Listagem de processos"] = lambda progress, settings=runtime_settings: self._listar_processos_job(
                settings,
                headless=headless,
                progress=progress,
                auto_credentials=auto_credentials,
                summary_only=False,
                use_filters=True,
            )

        if not tasks_to_run:
            QtWidgets.QMessageBox.information(self, "SEIAutomation", "Selecione ao menos uma tarefa.")
            return

        self._start_worker(tasks_to_run, operation="tasks")

    def _runtime_settings(self) -> Settings | None:
        username = self.input_username.text().strip()
        password = self.input_password.text().strip()
        if not username or not password:
            QtWidgets.QMessageBox.warning(self, "SEIAutomation", "Preencha usuário e senha antes de continuar.")
            return None
        self.settings = self.settings.with_updates(username=username, password=password)
        return self.settings

    def _start_dashboard_refresh(self) -> None:
        runtime_settings = self._runtime_settings()
        if runtime_settings is None:
            return

        tasks = {
            "Atualização do painel": lambda progress, settings=runtime_settings: self._listar_processos_job(
                settings,
                headless=self.checkbox_headless.isChecked(),
                progress=progress,
                auto_credentials=self.checkbox_auto_credentials.isChecked(),
                summary_only=True,
                use_filters=False,
            )
        }
        self._start_worker(tasks, operation="dashboard")

    def _listar_processos_job(
        self,
        settings: Settings,
        *,
        headless: bool,
        progress: Callable[[str], None],
        auto_credentials: bool,
        summary_only: bool,
        use_filters: bool,
    ) -> None:
        filtros = self._current_filter_kwargs() if use_filters else {}
        resultado = listar_processos(
            settings,
            headless=headless,
            progress=progress,
            auto_credentials=auto_credentials,
            summary_only=summary_only,
            **filtros,
        )
        self.summary_signal.emit(resultado.resumo)

        if summary_only and not resultado.processos:
            progress("Nenhum processo encontrado para o bloco/filtros atuais.")

    def _start_worker(self, tasks: Dict[str, Callable[[Callable[[str], None]], None]], operation: str) -> None:
        self._current_operation = operation
        self._set_controls_enabled(False)
        self.worker = Worker(tasks)
        self.worker.log_signal.connect(self._append_log)
        self.worker.finished_signal.connect(self._on_tasks_finished)
        self.worker.start()

    def _on_tasks_finished(self, success: bool, message: str) -> None:
        self._set_controls_enabled(True)
        self._append_log(message)
        if self._current_operation == "tasks":
            icon = QtWidgets.QMessageBox.Information if success else QtWidgets.QMessageBox.Warning
            QtWidgets.QMessageBox(icon, "SEIAutomation", message, QtWidgets.QMessageBox.Ok, self).exec()
        self._current_operation = None

    def _set_controls_enabled(self, enabled: bool) -> None:
        self.run_button.setEnabled(enabled)
        self.refresh_button.setEnabled(enabled)

    def _apply_summary(self, resumo: ResumoProcessos | None) -> None:
        if resumo is None:
            return
        self._last_summary = resumo
        self.summary_labels["total"].setText(str(resumo.total))
        self.summary_labels["ok"].setText(str(resumo.ok))
        self.summary_labels["pendentes"].setText(str(resumo.pendentes))
        self.summary_labels["baixados"].setText(str(resumo.baixados))
        self.summary_labels["faltando"].setText(str(resumo.faltando_zip))

    def _current_filter_kwargs(self) -> dict[str, bool]:
        annotation_choice = self.annotation_filter.currentData()
        zip_choice = self.zip_filter.currentData()
        return {
            "somente_pendentes": annotation_choice == "pending",
            "somente_ok": annotation_choice == "ok",
            "somente_baixados": zip_choice == "with_zip",
            "somente_sem_zip": zip_choice == "without_zip",
        }

    def closeEvent(self, event: QtGui.QCloseEvent) -> None:  # noqa: N802,D401
        self.hide()
        self.tray.showMessage("SEIAutomation", "Executando em segundo plano. Clique no ícone para reabrir.")
        event.ignore()


def run_gui(settings: Settings | None = None) -> None:
    import sys

    if settings is None:
        settings = Settings.load(allow_empty_credentials=True)

    app = QtWidgets.QApplication(sys.argv)
    window = MainWindow(settings)
    window.show()
    sys.exit(app.exec())
