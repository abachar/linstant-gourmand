"use client";

import { DefaultErrorComponent } from "@components/defaults";

export default function DefaultError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
	return <DefaultErrorComponent error={error} reset={reset} />;
}
