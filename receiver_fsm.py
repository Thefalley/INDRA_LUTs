"""Modelo software de la recepción del paquete de Task 2.

Formato de entrada cuando valid == True:
    i_first + i_data = x_max (número de columnas)
    siguiente i_data = y_max (número de filas)
    siguientes x_max * y_max bytes = matriz, por filas

Este fichero no resuelve todavía el recorrido ni genera salidas. Sólo permite
entender y probar la parte receptora antes de escribirla en SystemVerilog.
"""

from dataclasses import dataclass, field
from enum import Enum, auto


MAX_CELLS = 4090


class RxState(Enum):
    """Estados de la máquina receptora."""

    WAIT_FIRST = auto()  # Espera el comienzo de un paquete.
    READ_Y = auto()      # x_max ya se recibió; ahora llega y_max.
    READ_MATRIX = auto() # Recibe y guarda los valores de la matriz.


@dataclass
class MatrixReceiver:
    state: RxState = RxState.WAIT_FIRST
    columns: int = 0
    rows: int = 0
    matrix: list[list[int]] = field(default_factory=list)
    received_cells: int = 0

    def reset(self) -> None:
        """Equivalente conceptual a activar i_rst en hardware."""
        self.state = RxState.WAIT_FIRST
        self.columns = 0
        self.rows = 0
        self.matrix = []
        self.received_cells = 0

    def step(self, *, valid: bool, first: bool, last: bool, data: int) -> bool:
        """Consume un ciclo de entrada y devuelve True al terminar la matriz.

        Si valid es False, no se recibe ningún byte y el estado no cambia.
        `data` representa i_data y debe ser un byte sin signo (0..255).
        """
        if not valid:
            return False
        if not 0 <= data <= 0xFF:
            raise ValueError("data debe estar entre 0 y 255")

        if self.state is RxState.WAIT_FIRST:
            if not first:
                # En hardware se ignoraría el byte hasta detectar i_first.
                return False
            self.columns = data       # Primer byte de cabecera: x_max.
            self.state = RxState.READ_Y
            return False

        if self.state is RxState.READ_Y:
            self.rows = data          # Segundo byte de cabecera: y_max.
            total = self.columns * self.rows
            if total == 0 or total > MAX_CELLS:
                dimensions = f"{self.columns} x {self.rows}"
                self.reset()
                raise ValueError(f"Dimensiones inválidas: {dimensions}")

            # Reserva una matriz de rows filas y columns columnas.
            self.matrix = [[0 for _ in range(self.columns)] for _ in range(self.rows)]
            self.received_cells = 0
            self.state = RxState.READ_MATRIX
            return False

        # READ_MATRIX: convierte el contador lineal en coordenadas fila/columna.
        row = self.received_cells // self.columns
        col = self.received_cells % self.columns
        self.matrix[row][col] = data
        self.received_cells += 1

        complete = self.received_cells == self.rows * self.columns
        if complete:
            # i_last debe coincidir exactamente con la última celda.
            if not last:
                raise ValueError("Falta i_last en la última celda")
            self.state = RxState.WAIT_FIRST
            return True

        if last:
            raise ValueError("i_last llegó antes de recibir toda la matriz")
        return False


if __name__ == "__main__":
    # Ejemplo: matriz 3 columnas x 2 filas recibida por filas.
    rx = MatrixReceiver()
    stream = [
        # valid, first, last, data
        (True, True,  False, 3),  # x_max: 3 columnas
        (True, False, False, 2),  # y_max: 2 filas
        (True, False, False, 10),
        (True, False, False, 11),
        (True, False, False, 12),
        (True, False, False, 20),
        (True, False, False, 21),
        (True, False, True,  22),
    ]
    for valid, first, last, data in stream:
        if rx.step(valid=valid, first=first, last=last, data=data):
            print(rx.matrix)  # [[10, 11, 12], [20, 21, 22]]
