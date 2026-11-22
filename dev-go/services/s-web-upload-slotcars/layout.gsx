package module

import "github.com/gsxhq/gsx"

component Page(title string, children gsx.Node) {
	<!DOCTYPE html>
	<html lang="en">
		<head>
			<meta charset="utf-8"/>
			<meta name="viewport" content="width=device-width, initial-scale=1"/>
			<title>{title}</title>
			<style>
				:root {
					--bg: #f6f4ef;
					--card: #ffffff;
					--text: #24211d;
					--muted: #8c857b;
					--line: rgb(36 33 29 / 15%);
					--accent: #3c7f9e;
					--accent-soft: #e6f0f4;
					--error: #a8502a;
				}
				* {
					box-sizing: border-box;
				}
				body {
					font: 15px/1.4 system-ui, sans-serif;
					color: var(--text);
					background: var(--bg);
					max-width: 32rem;
					margin: 0 auto;
					padding: 2rem 1rem;
					-webkit-font-smoothing: antialiased;
				}
				h1 {
					font-size: 1.1rem;
					font-weight: 600;
					letter-spacing: 0.02em;
					margin: 0 0 1.5rem;
				}
				.upload + .upload {
					margin-top: 1.5rem;
				}
				.drop {
					display: flex;
					align-items: center;
					justify-content: center;
					min-height: 10rem;
					padding: 1.5rem;
					text-align: center;
					background: var(--card);
					border: 2px dashed var(--line);
					border-radius: 12px;
					cursor: pointer;
					transition: border-color 0.15s, background 0.15s;
				}
				.drop:hover, .drop.over {
					border-color: var(--accent);
					background: var(--accent-soft);
				}
				.drop input {
					display: none;
				}
				.status {
					margin: 0.75rem 0 0;
					color: var(--muted);
				}
				.status.error {
					color: var(--error);
				}
			</style>
		</head>
		<body>
			<h1>{title}</h1>
			{children}
			<script>
				for (const form of document.querySelectorAll("form.upload")) {
					const drop = form.querySelector(".drop");
					const input = form.querySelector("input");
					const status = form.querySelector(".status");

					function showStatus(message, isError) {
						status.textContent = message;
						status.classList.toggle("error", isError);
						status.hidden = false;
					}

					async function upload(file) {
						showStatus("Uploading " + file.name + "…", false);
						const body = new FormData();
						body.append("file", file);
						try {
							const response = await fetch(form.action, { method: "POST", body });
							if (!response.ok) {
								const isText = response.headers.get("Content-Type")?.startsWith("text/plain");
								throw new Error(isText ? (await response.text()).trim() : response.status + " " + response.statusText);
							}
							showStatus("Uploaded " + file.name, false);
						} catch (err) {
							showStatus("Failed to upload " + file.name + ": " + err.message, true);
						}
					}

					input.addEventListener("change", () => {
						if (input.files.length > 0) {
							upload(input.files[0]);
							input.value = "";
						}
					});

					drop.addEventListener("dragover", (event) => {
						event.preventDefault();
						drop.classList.add("over");
					});
					drop.addEventListener("dragleave", () => drop.classList.remove("over"));
					drop.addEventListener("drop", (event) => {
						event.preventDefault();
						drop.classList.remove("over");
						const file = event.dataTransfer.files[0];
						if (file) {
							upload(file);
						}
					});
				}
			</script>
		</body>
	</html>
}

component DropZone(action string, accept string, label string) {
	<form class="upload" method="post" action={action} enctype="multipart/form-data">
		<label class="drop">
			<input type="file" name="file" accept={accept}/>
			{label}
		</label>
		<p class="status" hidden></p>
	</form>
}
