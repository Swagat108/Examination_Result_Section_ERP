// Hero band: warm fill, serif headline, the single gold rule. Use once at the top of every page.
export function PageHero({ title, lead }: { title: string; lead?: string }) {
  return (
    <section className="band band-warm">
      <div className="container">
        <h1>{title}</h1>
        <div className="gold-rule" />
        {lead && <p className="lead">{lead}</p>}
      </div>
    </section>
  );
}
