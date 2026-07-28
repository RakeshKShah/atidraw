import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockGoogleAuthenticatedSession } from "../../helpers/mock-api.js";

async function getBox(page) {
  const canvas = page.locator("canvas");
  await expect(canvas).toBeVisible();
  const box = await canvas.boundingBox();
  if (!box) throw new Error("Canvas bounding box unavailable");
  return box;
}

test("drawing_object_is_ready_for_downstream_consumption", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "drawing_object_is_ready_for_downstream_consumption",
    testTitle: testInfo.title,
  });

  let contentType = "";
  let byteLength = 0;
  let firstBytes = [];

  await recorder.step("mock authenticated session and inspect multipart payload", async () => {
    await mockGoogleAuthenticatedSession(page);
    await page.route(/^https?:\/\/[^/]+\/api\/upload(?:\?.*)?$/, async (route) => {
      const buffer = route.request().postDataBuffer() || Buffer.alloc(0);
      byteLength = buffer.length;
      firstBytes = Array.from(buffer.subarray(0, 32));
      contentType = route.request().headers()["content-type"] || "";
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ ok: true, pathname: "drawings/downstream.jpg" }),
      });
    });
  });

  await recorder.step("create a simple shape on canvas", async () => {
    await page.goto("/draw");
    const box = await getBox(page);
    await page.mouse.move(box.x + box.width * 0.3, box.y + box.height * 0.3);
    await page.mouse.down();
    await page.mouse.move(box.x + box.width * 0.7, box.y + box.height * 0.3, { steps: 8 });
    await page.mouse.move(box.x + box.width * 0.5, box.y + box.height * 0.65, { steps: 8 });
    await page.mouse.move(box.x + box.width * 0.3, box.y + box.height * 0.3, { steps: 8 });
    await page.mouse.up();
  });

  await recorder.step("export via share action", async () => {
    await page.getByRole("button", { name: "Share my drawing" }).click();
  });

  await recorder.step("validate payload is a non-empty encoded image upload", async () => {
    expect(contentType).toContain("multipart/form-data");
    expect(byteLength).toBeGreaterThan(1000);
    expect(firstBytes.length).toBeGreaterThan(0);
    await expect(page.getByText("Drawing shared!")).toBeVisible();
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:drawing_object_is_ready_for_downstream_consumption");
  await recorder.save(testInfo);
});
