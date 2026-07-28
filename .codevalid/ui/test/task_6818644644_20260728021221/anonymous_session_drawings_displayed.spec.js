import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockAnonymousOnlySession,
  mockDrawingsList,
} from "../../helpers/mock-api.js";
import {
  anonymousDrawingsResponse,
} from "../../mock/mock-data.js";

test("Drawings are displayed and associated with anonymous context when user stays anonymous", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "anonymous_session_drawings_displayed",
    testTitle: testInfo.title,
  });

  await recorder.step("Mock anonymous session and anonymous drawings API");
  await mockAnonymousOnlySession(page);
  await mockDrawingsList(page, anonymousDrawingsResponse);

  await recorder.step("Open anonymous access page and verify anonymous sign-in button");
  await page.goto("/draw");
  await expect(page.getByRole("button", { name: "Sign-in anonymously" })).toBeVisible();

  await recorder.step("Open drawings index without social sign-in");
  await page.goto("/");

  await recorder.step("Assert anonymous drawings and anonymous identity copy are visible");
  await expect(page.getByRole("img", { name: "Anonymous drawing" })).toBeVisible();
  await expect(page.getByText("Anonymous User")).toBeVisible();
  await expect(page.getByRole("img", { name: "AI image generated of Anonymous drawing" })).toBeVisible();
  await expect(page.getByText("Google User")).toHaveCount(0);
  await expect(page.getByText("GitHub User")).toHaveCount(0);

  console.log("CODEVALID_TEST_ASSERTION_OK:anonymous_session_drawings_displayed");
  await recorder.save(testInfo);
});
