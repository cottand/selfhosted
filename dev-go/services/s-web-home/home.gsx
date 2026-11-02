package module

component Home(lights []light, listFailed bool) {
	<!DOCTYPE html>
	<html lang="en">
		<head>
			<meta charset="utf-8"/>
			<meta name="viewport" content="width=device-width, initial-scale=1"/>
			<title>Home</title>
			<style>
				body {
					font-family: system-ui, sans-serif;
					max-width: 32rem;
					margin: 2rem auto;
					padding: 0 1rem;
				}
				.light {
					padding: 0.75rem 1rem;
					margin-bottom: 0.5rem;
					border-radius: 0.5rem;
					background: #eee;
				}
				.light.on {
					background: #ffe9a8;
				}
				.row {
					display: flex;
					align-items: center;
					justify-content: space-between;
				}
				.toggle {
					width: 3.5rem;
					height: 2rem;
					border: none;
					border-radius: 1rem;
					background: #bbb;
					position: relative;
					cursor: pointer;
				}
				.toggle::after {
					content: "";
					position: absolute;
					top: 0.25rem;
					left: 0.25rem;
					width: 1.5rem;
					height: 1.5rem;
					border-radius: 50%;
					background: white;
					transition: left 0.15s;
				}
				.toggle.on {
					background: #e0a800;
				}
				.toggle.on::after {
					left: 1.75rem;
				}
				.toggle:disabled {
					opacity: 0.4;
					cursor: not-allowed;
				}
				.brightness {
					display: flex;
					align-items: center;
					gap: 0.75rem;
					margin-top: 0.5rem;
				}
				.brightness input {
					flex: 1;
				}
				.brightness output {
					min-width: 3rem;
					text-align: right;
				}
				#light-error {
					color: #a8502a;
				}
				@media (min-width: 50rem) {
					body {
						max-width: 62rem;
					}
					.plan {
						position: relative;
						aspect-ratio: 1094 / 800;
						background: url("/floorplan.svg") center / contain no-repeat;
					}
					.light {
						position: absolute;
						box-sizing: border-box;
						width: 9rem;
						margin: 0;
						padding: 0.5rem 0.6rem;
						transform: translate(-50%, -50%);
						box-shadow: 0 1px 4px rgb(0 0 0 / 30%);
					}
					.brightness output {
						min-width: 2.5rem;
					}
					.brightness input {
						min-width: 0;
					}
					#light-plug103 {
						left: 34.7%;
						top: 90%;
					}
					#light-rgb105 {
						width: 11rem;
						left: 63.1%;
						top: 35%;
					}
					#light-plug104 {
						left: 63.3%;
						top: 10.4%;
					}
					#light-rgb108 {
						width: 11rem;
						left: 81.8%;
						top: 87.5%;
					}
					#light-plug106 {
						left: 89.6%;
						top: 70%;
					}
				}
			</style>
		</head>
		<body>
			<h1>Lights</h1>
			{ if listFailed {
				<p>Could not load lights.</p>
			} }
			<p id="light-error" role="alert" hidden></p>
			<div class="plan">
				{ for _, l := range lights {
					<LightRow l={l}/>
				} }
			</div>
			<script>
				let draggedRow = null;
				let pendingRow = null;

				function applyRow(row) {
					document.getElementById(row.id)?.replaceWith(row);
				}

				function showRow(html) {
					const template = document.createElement("template");
					template.innerHTML = html;
					const row = template.content.firstElementChild;
					if (row.id === draggedRow) {
						pendingRow = row;
					} else {
						applyRow(row);
					}
				}

				document.addEventListener("pointerdown", (event) => {
					if (event.target.matches("input[type=range]")) {
						draggedRow = event.target.closest(".light").id;
					}
				});

				function endDrag() {
					// runs after the slider's change event, which needs the slider to still be there
					setTimeout(() => {
						draggedRow = null;
						if (pendingRow) {
							applyRow(pendingRow);
							pendingRow = null;
						}
					});
				}
				document.addEventListener("pointerup", endDrag);
				document.addEventListener("pointercancel", endDrag);

				document.addEventListener("submit", async (event) => {
					event.preventDefault();
					const error = document.getElementById("light-error");
					try {
						const response = await fetch(event.target.action, {
							method: "POST",
							headers: { "X-Row-Only": "true" },
							body: new URLSearchParams(new FormData(event.target, event.submitter)),
						});
						if (!response.ok) {
							throw new Error(await response.text());
						}
						error.hidden = true;
						showRow(await response.text());
					} catch (err) {
						error.textContent = err.message;
						error.hidden = false;
					}
				});

				new EventSource("/lights/events").addEventListener("light", (event) => showRow(event.data));
			</script>
		</body>
	</html>
}

component LightRow(l light) {
	<div id={ "light-" + l.ID } class={ "light", "on": l.Known && l.On }>
		<div class="row">
			<div>
				<strong>{l.ID}</strong>
				<div>
					{ if !l.Known {
						unknown
					} else if !l.On {
						off
					} else if l.Dimmable {
						on · {l.Brightness}%
					} else {
						on
					} }
				</div>
			</div>
			<form method="post" action={ "/lights/" + l.ID }>
				<button
					type="submit"
					name="on"
					value={l.NextOn()}
					class={ "toggle", "on": l.Known && l.On }
					aria-pressed={l.Pressed()}
					aria-label={ "Toggle " + l.ID }
					disabled={!l.Known}
				></button>
			</form>
		</div>
		{ if l.Dimmable && l.Known {
			<form class="brightness" method="post" action={ "/lights/" + l.ID }>
				<input
					type="range"
					name="brightness"
					min="1"
					max="100"
					value={l.Brightness}
					aria-label={ "Brightness of " + l.ID }
					oninput=js`this.nextElementSibling.value = this.value + '%'`
					onchange=js`this.form.requestSubmit()`
				/>
				<output>{l.Brightness}%</output>
			</form>
		} }
	</div>
}
