// Ícones em SVG, os mesmos do portfólio (src/components/icons.jsx), sem biblioteca.
// São decorativos (aria-hidden): o texto ou o aria-label ao lado é que descreve a ação.

function Icone({ children, tamanho = 16 }) {
  return (
    <svg
      width={tamanho}
      height={tamanho}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      {children}
    </svg>
  );
}

export function IconeSol(props) {
  return (
    <Icone {...props}>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2m0 16v2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M2 12h2m16 0h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
    </Icone>
  );
}

export function IconeLua(props) {
  return (
    <Icone {...props}>
      <path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5Z" />
    </Icone>
  );
}

export function IconeCodigo(props) {
  return (
    <Icone {...props}>
      <path d="m8 7-5 5 5 5m8-10 5 5-5 5" />
    </Icone>
  );
}

export function IconeSeta(props) {
  return (
    <Icone {...props}>
      <path d="M5 12h14m-6-6 6 6-6 6" />
    </Icone>
  );
}
