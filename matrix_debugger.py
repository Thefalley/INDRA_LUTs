"""Depurador visual mínimo de la recepción de una matriz.

Ejecuta:  python matrix_debugger.py
No necesita instalar librerías: tkinter viene con Python en Windows.
"""

import tkinter as tk
from tkinter import messagebox

from receiver_fsm import MatrixReceiver, RxState


class Debugger:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        root.title("Depurador - recepción de matriz")

        self.receiver = MatrixReceiver()
        self.stream: list[int] = []
        self.position = 0
        self.last_cell: tuple[int, int] | None = None

        controls = tk.Frame(root, padx=10, pady=10)
        controls.pack()

        tk.Label(controls, text="Columnas (x):").grid(row=0, column=0, sticky="e")
        self.x_entry = tk.Entry(controls, width=8)
        self.x_entry.insert(0, "3")
        self.x_entry.grid(row=0, column=1)

        tk.Label(controls, text="Filas (y):").grid(row=0, column=2, sticky="e")
        self.y_entry = tk.Entry(controls, width=8)
        self.y_entry.insert(0, "2")
        self.y_entry.grid(row=0, column=3)

        tk.Label(controls, text="Valores separados por comas:").grid(
            row=1, column=0, columnspan=2, sticky="e"
        )
        self.values_entry = tk.Entry(controls, width=35)
        self.values_entry.insert(0, "10, 11, 12, 20, 21, 22")
        self.values_entry.grid(row=1, column=2, columnspan=2)

        tk.Button(controls, text="Preparar paquete", command=self.prepare).grid(
            row=2, column=0, columnspan=2, pady=8
        )
        self.step_button = tk.Button(
            controls, text="Siguiente byte", command=self.step, state="disabled"
        )
        self.step_button.grid(row=2, column=2, columnspan=2, pady=8)

        self.status = tk.Label(root, text="Pulsa «Preparar paquete».", justify="left")
        self.status.pack(pady=4)

        self.grid_frame = tk.Frame(root, padx=10, pady=10)
        self.grid_frame.pack()
        self.cells: list[list[tk.Label]] = []

    def prepare(self) -> None:
        """Crea el flujo: x, y, y después los valores de la matriz."""
        try:
            columns = int(self.x_entry.get())
            rows = int(self.y_entry.get())
            values = [int(value.strip()) for value in self.values_entry.get().split(",")]
            if columns <= 0 or rows <= 0 or columns * rows > 4090:
                raise ValueError("Las dimensiones deben cumplir 1 <= x*y <= 4090")
            if len(values) != columns * rows:
                raise ValueError("Debes introducir exactamente x*y valores")
            if any(value < 0 or value > 255 for value in values):
                raise ValueError("Cada valor debe estar entre 0 y 255")
        except ValueError as error:
            messagebox.showerror("Datos inválidos", str(error))
            return

        self.receiver.reset()
        self.stream = [columns, rows] + values
        self.position = 0
        self.last_cell = None
        self.draw_empty_grid(rows, columns)
        self.step_button.config(state="normal")
        self.status.config(text="Estado: WAIT_FIRST. Aún no se ha leído ningún byte.")

    def step(self) -> None:
        """Simula un ciclo con i_valid=1 y muestra las señales de ese ciclo."""
        if self.position >= len(self.stream):
            return

        data = self.stream[self.position]
        first = self.position == 0
        last = self.position == len(self.stream) - 1
        before = self.receiver.state

        # Antes de guardar un valor de matriz calculamos su posición visual.
        self.last_cell = None
        if before is RxState.READ_MATRIX:
            index = self.receiver.received_cells
            self.last_cell = (index // self.receiver.columns, index % self.receiver.columns)

        complete = self.receiver.step(valid=True, first=first, last=last, data=data)
        self.position += 1
        self.refresh_grid()

        text = (
            f"Estado antes: {before.name}\n"
            f"i_valid=1, i_first={int(first)}, i_last={int(last)}, i_data={data}\n"
            f"Estado después: {self.receiver.state.name}"
        )
        if complete:
            text += "\n¡Matriz recibida correctamente!"
            self.step_button.config(state="disabled")
        self.status.config(text=text)

    def draw_empty_grid(self, rows: int, columns: int) -> None:
        for widget in self.grid_frame.winfo_children():
            widget.destroy()
        self.cells = []
        for row in range(rows):
            line: list[tk.Label] = []
            for col in range(columns):
                cell = tk.Label(self.grid_frame, text="·", width=5, relief="solid")
                cell.grid(row=row, column=col, padx=1, pady=1)
                line.append(cell)
            self.cells.append(line)

    def refresh_grid(self) -> None:
        for row, line in enumerate(self.cells):
            for col, cell in enumerate(line):
                value = self.receiver.matrix[row][col] if self.receiver.matrix else 0
                received = row * self.receiver.columns + col < self.receiver.received_cells
                cell.config(text=str(value) if received else "·", bg="white")
        if self.last_cell is not None:
            row, col = self.last_cell
            self.cells[row][col].config(bg="khaki")


if __name__ == "__main__":
    window = tk.Tk()
    Debugger(window)
    window.mainloop()
