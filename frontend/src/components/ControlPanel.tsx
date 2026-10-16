import type { ReactNode } from "react";

// Sits directly under the topbar on every page. Put search, filters and mass actions in `children`.
export function ControlPanel({ title, subtitle, children }: { title: string; subtitle?: string; children?: ReactNode }) {
  return (
    <div className="control-panel">
      <div>
        <h1>{title}</h1>
        {subtitle && <div className="cp-sub">{subtitle}</div>}
      </div>
      {children && <div className="cp-actions">{children}</div>}
    </div>
  );
}
